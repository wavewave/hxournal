module Application.HXournal.Iteratee.Eraser where

import Graphics.UI.Gtk

import Application.HXournal.Type.Event
import Application.HXournal.Type.Coroutine
import Application.HXournal.Type.XournalState
import Application.HXournal.Type.XournalBBox
import Application.HXournal.Type.Event
import Application.HXournal.Device
import Application.HXournal.HitTest
import Application.HXournal.Util.AlterList

import Application.HXournal.Iteratee.Default

--import Text.Xournal.Type 

import Control.Monad.Trans
import qualified Control.Monad.State as St

eraserStart :: PointerCoord -> Iteratee MyEvent XournalStateIO ()
eraserStart pcoord = do 
  liftIO $ putStrLn "eraser started"
  xstate <- lift St.get 
  let canvas = get drawArea xstate 
      xojbbox = get xournalbbox xstate
      pagenum = get currentPageNum xstate 
      page = (!!pagenum) . xournalPages $ xojbbox
      zmode = get (zoomMode.viewInfo) xstate 
      (x0,y0) = get (viewPortOrigin.viewInfo) xstate 
  geometry <- liftIO (getCanvasPageGeometry canvas page (x0,y0))
  let (x,y) = device2pageCoord geometry zmode pcoord 
  connidup <- connPenUp canvas
  connidmove <- connPenMove canvas 
  strs <- getAllStrokeBBoxInCurrentPage
  eraserProcess geometry connidup connidmove strs (x,y)
  
eraserProcess :: CanvasPageGeometry
              -> ConnectId DrawingArea -> ConnectId DrawingArea 
              -> [StrokeBBox] 
              -> (Double,Double)
              -> Iteratee MyEvent XournalStateIO ()
eraserProcess cpg connidmove connidup strs (x0,y0) = do 
  r <- await 
  xstate <- lift St.get 
  case r of 
    PenMove pcoord -> do 
      let zmode  = get (zoomMode.viewInfo) xstate
          (x,y) = device2pageCoord cpg zmode pcoord 
          line = ((x0,y0),(x,y))
          hittestbbox = mkHitTestBBox line strs   
          (hitteststroke,hitState) = 
            St.runState (hitTestStrokes line hittestbbox) False
      if hitState 
        then do 
          let currxoj     = get xournalbbox xstate 
              pgnum       = get currentPageNum xstate
              pages       = xournalPages currxoj 
              currpage    = pages !! pgnum
              pagesbefore = take pgnum pages 
              pagesafter  = drop (pgnum+1) pages 
              currlayer   = head (pageLayers currpage) 
              otherlayers = tail (pageLayers currpage) 
              (newstrokes,maybebbox) = St.runState (eraseHitted hitteststroke) Nothing
              newlayerbbox = currlayer { layerbbox_strokes = newstrokes }    
              newpagebbox = currpage 
                            { pagebbox_layers = newlayerbbox : otherlayers } 
              newxojbbox = currxoj { xojbbox_pages = pagesbefore
                                                     ++ [newpagebbox]
                                                     ++ pagesafter } 
          lift $ St.put (set xournalbbox newxojbbox xstate)
          case maybebbox of 
            Just bbox -> invalidateBBox bbox
            Nothing -> return ()
          newstrs <- getAllStrokeBBoxInCurrentPage
          eraserProcess cpg connidup connidmove newstrs (x,y)
        else       
          eraserProcess cpg connidmove connidup strs (x,y) 
    PenUp _pcoord -> do 
      liftIO $ signalDisconnect connidmove 
      liftIO $ signalDisconnect connidup 
      invalidate 
    _ -> return ()
    
eraseHitted :: AlterList NotHitted (AlterList NotHitted Hitted) 
               -> St.State (Maybe BBox) [StrokeBBox]
eraseHitted Empty = error "something wrong in eraseHitted"
eraseHitted (n :-Empty) = return (unNotHitted n)
eraseHitted (n:-h:-rest) = do 
  mid <- elimHitted h 
  return . (unNotHitted n ++) . (mid ++) =<< eraseHitted rest