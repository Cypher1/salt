
module Salt.Core.Eval.Term where
import Salt.Core.Eval.Data
import Salt.Core.Analysis.Support
import Salt.Core.Transform.MapAnnot
import Control.Exception
import qualified Salt.Core.Prim.Ops     as Ops
import qualified Data.Map               as Map
import qualified Data.Set               as Set


---------------------------------------------------------------------------------------------------
-- | Evaluate a term in the given environment.
evalTerm :: Annot a
         => a -> Env a -> Term a -> IO [Value a]

-- Pass through annotations.
evalTerm _a env (MAnn a' m)
 = evalTerm a' env m

-- References.
evalTerm _ _  (MRef (MRVal v))
 = return [v]

-- Variables
evalTerm a env (MVar u@(Bound n))
 = case envLookup n env of
        Just v  -> return [v]
        Nothing -> throw $ ErrorVarUnbound a u env

-- Function abstraction.
--   We trim the closure environment at the point the closure is
--   produced so that the closure is easier to read in debug logs.
evalTerm _a env (MAbm bts mBody)
 = do   let nsTermFree  = freeTermVarsOf mBody
        let Env nmsEnv  = env
        let env'        = Env [ (n, m) | (n, m) <- nmsEnv
                                       , Set.member n nsTermFree ]
        return [VClosure (CloTerm env' [MPTerms bts] mBody)]

-- Multi value return.
evalTerm a env (MKey MKTerms [MGTerms ms])
 = evalTerms a env ms

-- Prim-term application
evalTerm a env (MKey MKApp [MGTerm (MPrm nPrim), mgsArg])
 | case mgsArg of
        MGTerm{}  -> True
        MGTerms{} -> True
        _         -> False
 = case Map.lookup nPrim Ops.primOps of
        Just (Ops.PP _name _type step _docs)
         -> do  vsArg   <- evalTermArgs a env mgsArg
                let vsResult = step [] vsArg
                return vsResult

        Just (Ops.PO _name _type exec _docs)
         -> do  vsArg    <- evalTermArgs a env mgsArg
                vsResult <- exec [] vsArg
                return vsResult

        Nothing -> throw $ ErrorPrimUnknown a nPrim

-- Term-term application.
evalTerm a env (MKey MKApp [MGTerm mFun, mgsArg])
 = do   vsCloTerm <- evalTerm a env mFun
        case vsCloTerm of
         [VClosure (CloTerm env' [MPTerms bts] mBody)]
          -> do let bs    = map fst bts
                vsArg <- evalTermArgs a env mgsArg
                let env'' = envExtends (zip bs vsArg) env'
                vsRes <- evalTerm  a env'' mBody
                return vsRes
         [] -> throw $ ErrorAppTermNotEnough a []
         _  -> throw $ ErrorAppTermTooMany   a vsCloTerm

-- Let-binding.
evalTerm a env (MKey MKLet [MGTerms [mBind, MAbs (MPTerms bts) mBody]])
 = do   vsBind <- evalTerm a env mBind
        let nWanted = length bts
        let nHave   = length vsBind
        if  nWanted == nHave
         then do
                let bs = map fst bts
                let env' =  envExtends (zip bs vsBind) env
                vsResult <- evalTerm a env' mBody
                return vsResult
        else if nHave < nWanted
         then throw $ ErrorAppTermNotEnough a vsBind
        else  throw $ ErrorAppTermTooMany   a vsBind

-- Data constructor application.
evalTerm a env (MKey (MKCon nCon) [MGTypes ts, MGTerms msArg])
 = do   vsArg  <- evalTerms a env msArg
        return  [VData nCon ts vsArg]

-- Record constructor application.
evalTerm a env (MKey (MKRecord nsField) [MGTerms msArg])
 | length nsField == length msArg
 = do   vsArg <- evalTerms a env msArg
        return [VRecord $ zip nsField vsArg]

-- Record field projection.
evalTerm a env (MKey (MKProject nField) [MGTerms [mRecord]])
 = do   vRec  <- evalTerm1 a env mRecord
        case vRec of
         VRecord nvs
          -> case lookup nField nvs of
                Nothing -> throw $ ErrorProjectMissingField a vRec nField
                Just v  -> return [v]
         _ -> throw $ ErrorProjectTypeMismatch a vRec nField

-- List construction.
evalTerm a env (MKey MKList [MGTypes [t], MGTerms ms])
 = do   vsArg <- evalTerms a env ms
        return [VList t vsArg]

-- Set construction.
evalTerm a env (MKey MKSet  [MGTypes [t], MGTerms ms])
 = do   vsArg <- evalTerms a env ms
        return [VSet t $ Set.fromList $ map stripAnnot $ vsArg]

-- No match.
evalTerm  a _ mm
 =      throw $ ErrorInvalidConstruct a mm


---------------------------------------------------------------------------------------------------
-- | Like `evalTerm`, but expect a single result value.
evalTerm1
        :: Annot a
        => a -> Env a
        -> Term a -> IO (Value a)
evalTerm1 a env m
 = do   vs      <- evalTerm a env m
        case vs of
         [v]    -> return v
         []     -> throw $ ErrorAppTermNotEnough a []
         vs'    -> throw $ ErrorAppTermTooMany   a vs'


-- | Evaluate a list of terms, producing a single value for each.
evalTerms
        :: Annot a
        => a -> Env a
        -> [Term a] -> IO [Value a]
evalTerms a env ms
 = mapM (evalTerm1 a env) ms


---------------------------------------------------------------------------------------------------
evalTermArgs :: Annot a => a -> Env a -> TermArgs a -> IO [Value a]
evalTermArgs a env mgs
 = case mgs of
        MGTerm  m   -> evalTerm a env m
        MGTerms ms  -> mapM (evalTerm1 a env) ms
        MGTypes _   -> error "cannot evaluate type arguments"




