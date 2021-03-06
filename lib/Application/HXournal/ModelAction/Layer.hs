-----------------------------------------------------------------------------
-- |
-- Module      : Application.HXournal.ModelAction.Layer 
-- Copyright   : (c) 2011, 2012 Ian-Woo Kim
--
-- License     : BSD3
-- Maintainer  : Ian-Woo Kim <ianwookim@gmail.com>
-- Stability   : experimental
-- Portability : GHC
--
-----------------------------------------------------------------------------

module Application.HXournal.ModelAction.Layer where

import Application.HXournal.Util
import Application.HXournal.Type.Alias
import Control.Compose
import Control.Category
import Data.Label
import Prelude hiding ((.),id)
import Data.Xournal.Generic
import Data.Xournal.Select
import Graphics.UI.Gtk hiding (get,set)
import qualified Graphics.UI.Gtk as Gtk (get)
import Data.IORef

getCurrentLayerOrSet :: Page EditMode -> (Maybe (Layer EditMode), Page EditMode)
getCurrentLayerOrSet pg = 
  let olayers = get g_layers pg
      nlayers = case olayers of 
                  NoSelect _ -> selectFirst olayers
                  Select _ -> olayers  
  in case nlayers of
      NoSelect _ -> (Nothing, set g_layers nlayers pg)
      Select osz -> (return . current =<< unO osz, set g_layers nlayers pg)


adjustCurrentLayer :: Layer EditMode -> Page EditMode -> Page EditMode
adjustCurrentLayer nlayer pg = 
  let (molayer,pg') = getCurrentLayerOrSet pg
  in maybe (set g_layers (Select .O . Just . singletonSZ $ nlayer) pg')
           (const $ let layerzipper = maybe (error "adjustCurrentLayer") id . unO . zipper . get g_layers $  pg'
                    in set g_layers (Select . O . Just . replace nlayer $ layerzipper) pg' )
           molayer 

layerChooseDialog :: IORef Int -> Int -> Int -> IO Dialog
layerChooseDialog layernumref cidx len = do 
    dialog <- dialogNew 
    layerentry <- entryNew
    entrySetText layerentry (show (succ cidx))
    label <- labelNew (Just (" / " ++ show len))
    hbox <- hBoxNew False 0 
    upper <- dialogGetUpper dialog
    boxPackStart upper hbox PackNatural 0 
    boxPackStart hbox layerentry PackNatural 0 
    boxPackStart hbox label PackGrow 0 
    widgetShowAll upper
    buttonOk <- dialogAddButton dialog stockOk ResponseOk
    _buttonCancel <- dialogAddButton dialog stockCancel ResponseCancel

    buttonOk `on` buttonActivated $ do 
      txt <- Gtk.get layerentry entryText
      maybe (return ()) (modifyIORef layernumref . const . pred) . maybeRead $ txt
    return dialog


