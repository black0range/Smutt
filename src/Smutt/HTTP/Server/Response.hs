{-# LANGUAGE OverloadedStrings #-}
module Smutt.HTTP.Server.Response where

import qualified Data.ByteString as B



data Response = Manual | RawResponse Int [(B.ByteString,B.ByteString)] B.ByteString
 deriving (Show)






-- If the server should keep serving over the same connection
responseHasClose :: Response -> Bool
responseHasClose Manual = True
responseHasClose (RawResponse _ hdr _) = maybe False (=="close") (lookup "Connection" hdr)

