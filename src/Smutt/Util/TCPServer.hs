{-----------------------------------------------------------------------------------------
Module name: Smutt- a web server
Made by:     Tomas Möre 2014


Usage:  Pass a function of type (HTTPRequest -> IO Response) to the |serve| fucntion exported by module
        yor function is now responsible for putting together the response.
        An empty response will be treated as a |200 OK| without any content

        This library uses STRICT strings internally.



Notes for editor: Many functions are splitted into two parts, Any function with the postfix "Real"
                  has a initating function with the same name but without the postfix

------------------------------------------------------------------------------------------}
{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Smutt.Util.TCPServer
( makeTCPServer
, ServerThunk
, module Smutt.HTTP.Server.Settings
,
) where


import qualified Control.Exception as E

import System.IO
import System.IO.Error

import Control.Concurrent
import Control.Monad

import Network.Socket

import Data.IORef
import Data.Maybe
import Data.Either

import Smutt.HTTP.Server.Settings
import qualified Network.BufferedSocket as BS

type ServerThunk = (BS.BufferedSocket -> IO ())




makeTCPServer :: ServerThunk -> ServerSettings -> IO ()
makeTCPServer thunk serverSettings = withSocketsDo $ do

    -- create socket
    sock <- socket AF_INET Stream 0
    -- make socket immediately reusable - eases debugging.
    setSocketOption sock ReuseAddr 1

    --setSocketOption sock NoDelay 1


    -- listen on TCP port 8000
    bindSocket sock (SockAddrInet (port serverSettings) iNADDR_ANY)

    -- Tells the socket that it can have max 1000 connections
    listen sock $ maxConnections serverSettings

    let
        maybeKeepServingRef = keepServing serverSettings
        Just keepServingRef = maybeKeepServingRef

        threadTakeover = do
                            socketData <- accept sock
                            newThread <- forkIO (connectionHandler socketData thunk serverSettings)
                            return ()

        keepGoingFun   = do
                           serveAnother <- readIORef keepServingRef
                           if serveAnother
                                then
                                    threadTakeover >>
                                        keepGoingFun
                                else
                                    return ()

        choseServingMethod  = case isNothing maybeKeepServingRef of
                                    True  -> forever threadTakeover
                                    False -> keepGoingFun

    -- Makes sure that whatever happends ce close the socket.
    choseServingMethod `E.onException` (sClose sock)


connectionHandler :: (Socket, SockAddr) -> ServerThunk -> ServerSettings -> IO ()
connectionHandler fullSock@(sock, sockAddr) thunk settings =
    do
        -- Defining a prepared sending procedure. This procedure is sent around to all functions that might need to send data
        bSocket    <- BS.makeBufferedSocket fullSock  (readBufferSize settings) (writeBufferSize settings)
        --getTcpNoDelay sock >>= putStrLn . show

        case (socketKeepAlive settings) of
            True  ->  setSocketOption sock KeepAlive 1
            False -> return ()

        thunk bSocket

        sClose sock
    where
        bufferSize = readBufferSize settings
