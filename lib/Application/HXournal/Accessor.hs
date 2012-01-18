{-# LANGUAGE TypeOperators #-}

-----------------------------------------------------------------------------
-- |
-- Module      : Application.HXournal.Accessor 
-- Copyright   : (c) 2011, 2012 Ian-Woo Kim
--
-- License     : BSD3
-- Maintainer  : Ian-Woo Kim <ianwookim@gmail.com>
-- Stability   : experimental
-- Portability : GHC
--

module Application.HXournal.Accessor where

import Application.HXournal.Type
import Application.HXournal.Draw 
import Application.HXournal.ModelAction.Page


import Control.Applicative
import Control.Monad
import qualified Control.Monad.State as St
import Control.Monad.Trans
import Control.Category
import qualified Data.IntMap as M
import Data.Label
import Prelude hiding ((.),id)
import Graphics.UI.Gtk hiding (get,set)

import Control.Compose
import Graphics.Xournal.Render.BBoxMapPDF
import Data.Xournal.BBox
import Data.Xournal.Generic
import Data.Xournal.Buffer
import Data.Xournal.Select

import Application.HXournal.Util
import Application.HXournal.ModelAction.Layer 


getSt :: MainCoroutine HXournalState -- Iteratee MyEvent XournalStateIO HXournalState
getSt = lift St.get

putSt :: HXournalState -> MainCoroutine () -- Iteratee MyEvent XournalStateIO ()
putSt = lift . St.put


adjustments :: CanvasInfo :-> (Adjustment,Adjustment) 
adjustments = Lens $ (,) <$> (fst `for` horizAdjustment)
                         <*> (snd `for` vertAdjustment)

getPenType :: Iteratee MyEvent XournalStateIO PenType
getPenType = get (penType.penInfo) <$> lift (St.get)
      
getAllStrokeBBoxInCurrentPage :: MainCoroutine [StrokeBBox] 
getAllStrokeBBoxInCurrentPage = do 
  xstate <- getSt 
  let currCvsInfo  = getCurrentCanvasInfo xstate 
  let pagebbox = getPage currCvsInfo
      strs = do 
        l <- gToList (get g_layers pagebbox)
        s <- get g_bstrokes l
        return s 
  return strs 

getAllStrokeBBoxInCurrentLayer :: MainCoroutine [StrokeBBox] 
getAllStrokeBBoxInCurrentLayer = do 
  xstate <- getSt 
  let currCvsInfo  = getCurrentCanvasInfo xstate 
  let pagebbox = getPage currCvsInfo
      (mcurrlayer, currpage) = getCurrentLayerOrSet pagebbox
      currlayer = maybe (error "getAllStrokeBBoxInCurrentLayer") id mcurrlayer
  return (get g_bstrokes currlayer)
      
      
updateCanvasInfo :: CanvasInfo -> HXournalState -> HXournalState
updateCanvasInfo cinfo xstate = 
  let cid = get canvasId cinfo
      cmap = get canvasInfoMap xstate
      cmap' = M.adjust (const cinfo) cid cmap 
      xstate' = set canvasInfoMap cmap' xstate
  in xstate' 
 
otherCanvas :: HXournalState -> [Int] 
otherCanvas = M.keys . get canvasInfoMap 

changeCurrentCanvasId :: CanvasId -> MainCoroutine HXournalState -- Iteratee MyEvent XournalStateIO HXournalState
changeCurrentCanvasId cid = do xstate1 <- getSt 
                               let xstate = set currentCanvas cid xstate1
                               putSt xstate
                               return xstate
                               
getCanvasInfo :: CanvasId -> HXournalState -> CanvasInfo 
getCanvasInfo cid xstate = 
  let cinfoMap = get canvasInfoMap xstate
      maybeCvs = M.lookup cid cinfoMap
  in maybeError ("no canvas with id = " ++ show cid) maybeCvs
{-  in  case maybeCvs of 
        Nothing -> error $ "no canvas with id = " ++ show cid 
        Just cvsInfo -> cvsInfo -}

getCurrentCanvasInfo :: HXournalState -> CanvasInfo 
getCurrentCanvasInfo xstate = getCanvasInfo (get currentCanvas xstate) xstate
      

getCanvasGeometry :: CanvasInfo -> MainCoroutine CanvasPageGeometry -- Iteratee MyEvent XournalStateIO CanvasPageGeometry
getCanvasGeometry cinfo = do 
    let canvas = get drawArea cinfo
        page = getPage cinfo
        (x0,y0) = get (viewPortOrigin.viewInfo) cinfo
    liftIO (getCanvasPageGeometry canvas page (x0,y0))


