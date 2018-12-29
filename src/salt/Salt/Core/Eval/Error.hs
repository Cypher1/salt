
module Salt.Core.Eval.Error where
import Salt.Core.Exp
import Data.Typeable
import Control.Exception


data Error a
        -- | Generic error when we don't know how to handle a construct.
        = ErrorInvalidConstruct
        { errorAnnot            :: a
        , errorTerm             :: Term a }

        -- | Wrong number of types for eliminator.
        | ErrorWrongTypeArity
        { errorAnnot            :: a
        , errorNumExpected      :: Int
        , errorTypes            :: [Type a] }

        -- | Wrong number of terms for eliminator.
        | ErrorWrongTermArity
        { errorAnnot            :: a
        , errorNumExpected      :: Int
        , errorValues           :: [Value a] }

        -- Varaibles --------------------------------------
        -- | Type variable binding is not in the environment.
        | ErrorTypeVarUnbound
        { errorAnnot            :: a
        , errorVarUnbound       :: Bound
        , errorTypeEnv          :: TypeEnv a }

        -- | Term variable binding is not in the environment.
        | ErrorTermVarUnbound
        { errorAnnot            :: a
        , errorVarUnbound       :: Bound
        , errorTermEnv          :: TermEnv a }

        -- Applications -----------------------------------
        -- | Runtime type error in application,
        --   as the functional expression is not a closure.
        | ErrorAppTermTypeMismatch
        { errorAnnot            :: a
        , errorAppNotClo        :: Value a }

        -- | Runtime type error in application,
        --   because the function produced too many results.
        | ErrorAppTermBadClosure
        { errorAnnot            :: a
        , errorValues           :: [Value a] }

        -- | Runtime type error in application
        --   because the sort of parameters does not match the sort of arguments.
        | ErrorAppTermWrongArgs
        { errorAnnot            :: a
        , errorParams           :: TermParams a
        , errorArgs             :: TermArgs a }

        -- | Unknown primitive operator.
        | ErrorPrimUnknown
        { errorAnnot            :: a
        , errorPrimUnknown      :: Name }

        -- | Runtime type error in a primitive.
        | ErrorPrimTypeMismatch
        { errorAnnot            :: a
        , errorPrimName         :: Name
        , errorPrimArgs         :: [Value a] }

        -- Records ----------------------------------------
        -- | Runtime type error in record projection.
        | ErrorProjectNotRecord
        { errorAnnot            :: a
        , errorProjectNotRecord :: Value a
        , errorProjectField     :: Name }

        -- | Missing field in record projection.
        | ErrorProjectMissingField
        { errorAnnot            :: a
        , errorProjectRecord    :: Value a
        , errorProjectField     :: Name }

        -- Variants --------------------------------------
        | ErrorCaseScrutNotVariant
        { errorAnnot            :: a
        , errorCaseScrut        :: Value a }

        | ErrorCaseNoMatch
        { errorAnnot            :: a
        , errorCaseScrut        :: Value a }

        -- If-then-else -----------------------------------
        -- | Scrutinee in 'ifs' construct is not a boolean value.
        | ErrorIfsScrutNotBool
        { errorAnnot            :: a
        , errorValue            :: Value a }

        -- Suspensions ------------------------------------
        -- | Value to run is not a suspension.
        | ErrorRunNotSuspension
        { errorAnnot            :: a
        , errorValue            :: Value a }

        deriving Show

instance (Show a, Typeable a) => Exception (Error a)

