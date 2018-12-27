
module Salt.Core.Check.Module.DeclTest where
import Salt.Core.Check.Module.Base
import Salt.Core.Check.Term.Base
import Salt.Core.Check.Type.Base
import qualified Salt.Data.List as List
import qualified Data.Set       as Set


-- | Check test declarations.
checkDeclTest :: CheckDecl a

-- (t-decl-kind) ------------------------------------------
checkDeclTest _a ctx (DTest (DeclTestKind a' n t))
 = do   let wh = [WhereTestDecl a' n]
        (t', _k) <- checkType a' wh ctx t
        return  $ DTest $ DeclTestKind a' n t'


-- (t-decl-type) ------------------------------------------
checkDeclTest _a ctx (DTest (DeclTestType a' n m))
 = do   let wh  = [WhereTestDecl a' n]
        (m', _tResult, _esResult)
         <- checkTerm a' wh ctx Synth m
        return  $ DTest $ DeclTestType a' n m'


-- (t-decl-eval) ------------------------------------------
checkDeclTest _a ctx (DTest (DeclTestEval a' n m))
 = do   let wh  = [WhereTestDecl a' n]
        (m', _tResult, _esResult)
         <- checkTerm a' wh ctx Synth m

        -- TODO: check effects are empty.
        return  $ DTest $ DeclTestEval a' n m'


-- (t-decl-exec) ------------------------------------------
checkDeclTest _a ctx (DTest (DeclTestExec a' n m))
 = do   let wh  = [WhereTestDecl a' n]
        (m', _tResult, _esResult)
         <- checkTerm a' wh ctx Synth m

        -- TODO: check effects are empty.
        -- TODO: check expr returns a suspension
        return  $ DTest $ DeclTestExec a' n m'


-- (t-decl-assert) ----------------------------------------
checkDeclTest _a ctx (DTest (DeclTestAssert a' n m))
 = do   let wh  = [WhereTestDecl a' n]
        (m', _tResult, _esResult)
         <- checkTerm a' wh ctx (Check [TBool]) m

        -- TODO: check effects are empty.
        return  $ DTest $ DeclTestAssert a' n m'

checkDeclTest _a _ctx decl
 = return decl


-- | Check for rebound test declarations.
checkDeclTestRebound :: Annot a => [Decl a] -> [Error a]
checkDeclTestRebound decls
 = let  nsDeclTerm = catMaybes [nameOfDecl d | d@DTest{} <- decls]
        nsDup      = Set.fromList $ List.duplicates nsDeclTerm

        check decl@(DTest _)
         | aDecl        <- annotOfDecl decl
         , Just nDecl   <- nameOfDecl  decl
         , Set.member nDecl nsDup
         = Just $ ErrorTestDeclRebound aDecl [WhereTestDecl aDecl (Just nDecl)] nDecl
        check _ = Nothing

   in   mapMaybe check decls

