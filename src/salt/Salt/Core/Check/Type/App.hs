
module Salt.Core.Check.Type.App where
import Salt.Core.Check.Type.Base


-- | Check the application of a type to some types.
checkTypeAppTypes
        :: Annot a => a -> [Where a]
        -> Context a -> Kind a -> TypeArgs a
        -> IO (TypeArgs a, Kind a)

checkTypeAppTypes _a wh ctx kFun (TGAnn a tgs')
 = checkTypeAppTypes a wh ctx kFun tgs'

checkTypeAppTypes a  wh ctx kFun (TGTypes tsArg)
 = case kFun of
        TArr ksParam kResult
          -> goCheckArgs ksParam kResult
        _ -> throw $ ErrorAppTypeTypeCannot a wh kFun
 where
        goCheckArgs ksParam kResult
         = if length ksParam /= length tsArg
             then throw $ ErrorAppTypeTypeWrongArityNum a wh ksParam (length tsArg)
             else do
                (tsArg', ksArg) <- checkTypes a wh ctx tsArg
                goCheckParams ksParam kResult (TGTypes tsArg') ksArg

        goCheckParams ksParam kResult tsArg' ksArg
         = checkTypeEquivs ctx a [] ksParam a [] ksArg
         >>= \case
                Nothing -> return (tsArg', kResult)
                Just ((_aErrParam, kErrParam), (aErrArg', kErrArg))
                 -> throw $ ErrorTypeMismatch aErrArg' wh kErrArg kErrParam
