
module Salt.Core.Check.Context where
import Salt.Core.Transform.Ups
import Salt.Core.Check.Where
import Salt.Core.Exp
import qualified Salt.Core.Prim.Ctor    as Prim

import Data.Map.Strict                  (Map)
import qualified Data.Map               as Map


---------------------------------------------------------------------------------------------------
data Mode a
        = Synth
        | Check [Type a]
        deriving Show


---------------------------------------------------------------------------------------------------
data Elem a
        = ElemTypes (Map Name (Kind a))
        | ElemTerms (Map Name (Type a))
        deriving Show


data Context a
        = Context
        { -- | Function to check a type.
          --   We hold a reference to the checker here o tie the mutually recursive
          --   knot without needing mutually recursive modules.
          contextCheckType      :: CheckType a

          -- | Function to check a term.
        , contextCheckTerm      :: CheckTerm a

          -- | Kinds and bodies of top-level type bindings in the current module.
        , contextModuleType     :: Map Name (Kind a, Type a)

          -- | Types of top-level term bindings in the current module.
        , contextModuleTerm     :: Map Name (Type a)

          -- | Holds types of local name bindings.
          --   This is used for bindings within a single top-level declaration.
        , contextLocal          :: [Elem a]
        }


type CheckType a
        =  Annot a => a -> [Where a]
        -> Context a -> Type a
        -> IO (Type a, Kind a)


type CheckTerm a
        =  Annot a => a -> [Where a]
        -> Context a -> Mode a -> Term a
        -> IO (Term a, [Type a], [Effect a])


---------------------------------------------------------------------------------------------------
-- | Bind a single type variable into the context.
contextBindType :: Name -> Type a -> Context a -> Context a
contextBindType n t ctx
 = ctx  { contextLocal = ElemTypes (Map.singleton n t) : contextLocal ctx }


-- | Bind a single type variable into the context, if we have one.
contextBindTypeMaybe :: Maybe Name -> Type a -> Context a -> Context a
contextBindTypeMaybe Nothing _t ctx = ctx
contextBindTypeMaybe (Just n) t ctx
 = ctx  { contextLocal = ElemTypes (Map.singleton n t) : contextLocal ctx }


-- | Bind a list of type variables all at the same level.
contextBindTypes :: [(Name, Kind a)] -> Context a -> Context a
contextBindTypes nts ctx
 = ctx  { contextLocal = ElemTypes (Map.fromList nts) : contextLocal ctx }


-- | Bind the kinds of type parameters into the context.
contextBindTypeParams :: TypeParams a -> Context a -> Context a
contextBindTypeParams (TPTypes bts) ctx
 = flip contextBindTypes ctx [ (n, t) | (BindName n, t) <- bts ]


---------------------------------------------------------------------------------------------------
-- | Bind a single term variable into the context.
contextBindTerm :: Name -> Type a -> Context a -> Context a
contextBindTerm n t ctx
 = ctx  { contextLocal = ElemTerms (Map.singleton n t) : contextLocal ctx }


-- | Bind a single term variable into the context, if we have one.
contextBindTermMaybe :: Maybe Name -> Type a -> Context a -> Context a
contextBindTermMaybe Nothing _t ctx = ctx
contextBindTermMaybe (Just n) t ctx
 = ctx  { contextLocal = ElemTerms (Map.singleton n t) : contextLocal ctx }


-- | Bin a list of term variables all at the same level.
contextBindTerms :: [(Name, Type a)] -> Context a -> Context a
contextBindTerms nts ctx
 = ctx  { contextLocal = ElemTerms (Map.fromList nts) : contextLocal ctx }


-- | Bind the types of term parameters into the context.
contextBindTermParams :: TermParams a -> Context a -> Context a
contextBindTermParams mps ctx
 = case mps of
        MPTypes bts
         -> flip contextBindTypes ctx [ (n, t) | (BindName n, t) <- bts ]

        MPTerms bts
         -> flip contextBindTerms ctx [ (n, t) | (BindName n, t) <- bts ]


---------------------------------------------------------------------------------------------------
-- | Lookup a bound type variable from the context.
--
--   * If it is transparanetly bound as a synonym we get both the kind and body type,
--   * If it is opaquely bound by an abstraction we get just the kind.
--
contextResolveTypeBound
        :: Context a
        -> [TypeParams a]
        -> Bound
        -> IO (Maybe (TypeDef a))

contextResolveTypeBound ctx ps0 (BoundWith n d0)
 = goParams 0 d0 upsEmpty ps0
 where
        -- Look through parameters
        goParams level d ups (TPTypes bks : tpss)
         = let ups' = upsCombine ups (upsOfBinds $ map fst bks) in
           case lookup (BindName n) bks of
            Nothing      -> goParams (level + 1) d ups' tpss
            Just k
             | d == 0    -> return $ Just $ TypeParam k level
             | otherwise -> goParams (level + 1) (d - 1) ups' tpss

        goParams level d ups []
         = goLocal level d ups (contextLocal ctx)

        -- Look through the local context.
        goLocal level d ups (ElemTypes nks : rest)
         | d < 0    = return Nothing
         | otherwise
         = let ups' = upsCombine ups (upsOfNames $ Map.keys nks) in
           case Map.lookup n nks of
            Nothing      -> goLocal (level + 1) d ups' rest
            Just k
             | d == 0    -> return $ Just $ TypeLocal k level
             | otherwise -> goLocal (level + 1) (d - 1) ups' rest

        goLocal level d ups (ElemTerms{} : rest)
         = goLocal level d ups rest

        goLocal _level d ups []
         | d == 0       = goGlobal ups
         | otherwise    = return Nothing

        -- Look for synonyms in the global context.
        goGlobal ups
         = case Map.lookup n (contextModuleType ctx) of
            Nothing     -> return $ Nothing
            Just (k, t) -> return $ Just $ TypeDecl k (upsApplyType ups t)


---------------------------------------------------------------------------------------------------
-- | Lookup a bound term variable from the context.
---
--   If the there are type binders between the point where a type is used
--   and where it is defined then we need to lift free variables in that type
--   over the binders. For example:
--
-- @
--    λ\@[a: #Data]. λ[x: a]. λ\@[a: #Data]. x
-- @
--
--   At the inner use site the type of `x` is `a^1`, referring to the outer
--   most binder, not `a^0` referring to the inner one. When we search the
--   context for the binding site we build an `Ups` that records the names
--   of binders we need to bump in the resulting type, and apply it before
--   returning the type.
--
contextResolveTermBound :: Context a -> Bound -> IO (Maybe (Type a))
contextResolveTermBound ctx (BoundWith n d0)
 = goLocal d0 upsEmpty (contextLocal ctx)
 where
        -- See if this local binder is the one we are looking for.
        goLocal d ups (ElemTerms nts : rest)
         | d < 0        = return Nothing
         | otherwise
         = case Map.lookup n nts of
                Nothing -> goLocal d ups rest
                Just t
                 | d == 0       -> return $ Just $ upsApplyType ups t
                 | otherwise    -> goLocal (d - 1) ups rest

        goLocal d ups (ElemTypes mp : rest)
         = let  ups'    = upsCombine ups (upsOfNames $ Map.keys mp)
           in   goLocal d ups' rest

        goLocal d ups []
         | d == 0       = goGlobal ups
         | otherwise    = return Nothing

        -- Look for declarations in the global context.
        --  The types of top level terms should all be closed,
        --  but apply the ups anyway to be consistent in case they
        --  are not actually closed.
        goGlobal ups
         = case Map.lookup n (contextModuleTerm ctx) of
                Nothing -> return $ Nothing
                Just t  -> return $ Just $ upsApplyType ups t


-- | Lookup the parameter and result types of a data constructor.
contextResolveDataCtor :: Name -> Context a -> IO (Maybe (Type ()))
contextResolveDataCtor nCtor _ctx
 = return $ Map.lookup nCtor Prim.primDataCtors

