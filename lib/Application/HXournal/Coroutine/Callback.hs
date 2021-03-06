{-# LANGUAGE FlexibleContexts #-}

-----------------------------------------------------------------------------
-- |
-- Module      : Application.HXournal.Coroutine.Callback 
-- Copyright   : (c) 2011, 2012 Ian-Woo Kim
--
-- License     : BSD3
-- Maintainer  : Ian-Woo Kim <ianwookim@gmail.com>
-- Stability   : experimental
-- Portability : GHC
--
-----------------------------------------------------------------------------

module Application.HXournal.Coroutine.Callback where

import Control.Monad.Coroutine 
import Control.Monad.State
import Control.Monad.Coroutine.SuspensionFunctors
import Data.IORef
import Application.HXournal.Type.Coroutine
import Application.HXournal.Type.XournalState
import Application.HXournal.Type.Event 

dummycallback :: MyEvent -> IO ()
dummycallback = const (return ())

bouncecallback :: TRef -> SRef -> MyEvent -> IO () 
bouncecallback tref sref input = do 
  Await cont <- readIORef tref 
  st <- readIORef sref
  when (not (_isEventBlocked st)) $ do 
    (nr,st') <- runStateT (resume (cont input)) st 
    case nr of  
      Left  naw -> do writeIORef tref naw 
                      writeIORef sref st'
      Right val -> do putStrLn $ show val 
                      writeIORef tref (Await (\_ -> return ()))
                      writeIORef sref st'
    return ()  

