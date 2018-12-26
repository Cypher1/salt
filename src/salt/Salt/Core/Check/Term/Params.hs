
module Salt.Core.Check.Term.Params where
import Salt.Core.Check.Kind
import Salt.Core.Check.Term.Base
import Salt.Core.Check.Type.Base
import qualified Salt.Data.List as List


-- | Check some term function parameters.
checkTermParams
        :: Annot a => a -> [Where a]
        -> Context a -> TermParams a -> IO (TermParams a)

checkTermParams a wh ctx mps
 = case mps of
        MPTypes bks
         -> do  let (bs, ks) = unzip bks

                -- Check for duplicate binder names.
                let ns          = [ n | BindName n <- bs]
                let nsDup       = List.duplicates ns
                when (not $ null nsDup)
                 $ throw $ ErrorAbsTypeBindConflict a wh nsDup

                -- Check the parameter kinds.
                ks' <- mapM (checkKind a wh ctx) ks
                return  $ MPTypes $ zip bs ks'

        MPTerms bts
         -> do  let (bs, ts)    = unzip bts

                -- Check for duplicate binder names.
                let ns          = [ n | BindName n <- bs]
                let nsDup       = List.duplicates ns
                when (not $ null nsDup)
                 $ throw $ ErrorAbsTermBindConflict a wh nsDup

                -- Check the parameter types.
                ts' <- checkTypesAre a wh ctx (replicate (length ts) TData) ts
                return  $ MPTerms $ zip bs ts'


-- | Check a list of term function parameters,
--   where type variables bound earlier in the list are in scope
--   when checking types annotating term variables later in the list.
checkTermParamss
        :: Annot a => a -> [Where a]
        -> Context a -> [TermParams a] -> IO [TermParams a]

checkTermParamss _a _wh _ctx []
 = return []

checkTermParamss a wh ctx (tps : tpss)
 = do   tps'  <- checkTermParams  a wh ctx  tps
        let ctx'  = contextBindTermParams tps' ctx
        tpss' <- checkTermParamss a wh ctx' tpss
        return $ tps' : tpss'

