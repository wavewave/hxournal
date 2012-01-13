module Application.HXournal.Coroutine.Page where

import Control.Applicative 
import Control.Compose
import Application.HXournal.Type.Event
import Application.HXournal.Type.Coroutine
import Application.HXournal.Type.Canvas
import Application.HXournal.Type.XournalState
import Application.HXournal.Draw
import Application.HXournal.Accessor
import Application.HXournal.Coroutine.Draw
import Application.HXournal.Coroutine.Commit
import Application.HXournal.ModelAction.Adjustment

import Graphics.Xournal.Render.BBoxMapPDF
import Data.Xournal.Generic
import Data.Xournal.Select 

import Graphics.UI.Gtk hiding (get,set)
import Application.HXournal.ModelAction.Page

import Control.Monad.Trans
import Control.Category
import Data.Label
import Prelude hiding ((.), id)
import Data.Xournal.Simple
import qualified Data.IntMap as IM

changePage :: (Int -> Int) -> Iteratee MyEvent XournalStateIO () 
changePage modifyfn = do 
    xstate <- getSt 
    let currCvsId = get currentCanvas xstate
        currCvsInfo = getCanvasInfo currCvsId xstate   
    let xojst = get xournalstate $ xstate 
    case xojst of 
      ViewAppendState xoj -> do 
        let pgs = gpages xoj 
            totalnumofpages = IM.size pgs
            oldpage = get currentPageNum currCvsInfo
            lpage = case IM.lookup (totalnumofpages-1) pgs of
                      Nothing -> error "error in changePage"
                      Just p -> p            
        (xstate',xoj',_pages',_totalnumofpages',newpage) <-
          if (modifyfn oldpage >= totalnumofpages) 
          then do 
            let npage = newSinglePageFromOld lpage
                -- npage = lpage { glayers = IM.insert 0 (GLayerBuf (LyBuf Nothing) []) IM.empty } 
                npages = IM.insert totalnumofpages npage pgs 
                newxoj = xoj { gpages = npages } 
                xstate' = set xournalstate (ViewAppendState newxoj) xstate
            commit xstate'
            return (xstate',newxoj,npages,totalnumofpages+1,totalnumofpages)
          else if modifyfn oldpage < 0 
                 then return (xstate,xoj,pgs,totalnumofpages,0)
                 else return (xstate,xoj,pgs,totalnumofpages,modifyfn oldpage)
        let Dim w h = gdimension lpage
            (hadj,vadj) = get adjustments currCvsInfo
        liftIO $ do 
          adjustmentSetUpper hadj w 
          adjustmentSetUpper vadj h 
          adjustmentSetValue hadj 0
          adjustmentSetValue vadj 0
        let currCvsInfo' = setPage (ViewAppendState xoj') newpage currCvsInfo 
            xstate'' = updatePageAll (ViewAppendState xoj')
                       . updateCanvasInfo currCvsInfo' 
                       $ xstate'
        putSt xstate'' 
        invalidate currCvsId 
      SelectState txoj -> do 
        let pgs = gselectAll txoj 
            totalnumofpages = IM.size pgs
            oldpage = get currentPageNum currCvsInfo
            lpage = case IM.lookup (totalnumofpages-1) pgs of
                      Nothing -> error "error in changePage"
                      Just p -> p            
        (xstate',txoj',_pages',_totalnumofpages',newpage) <-
          if (modifyfn oldpage >= totalnumofpages) 
          then do
            nlyr <- liftIO emptyTLayerBBoxBufLyBuf  
            let npage = set g_layers (Select . O . Just . singletonSZ $ nlyr) lpage 
                         -- set g_layers (nlyr) lpage 
                        -- lpage { glayers = IM.insert 0 (GLayerBuf (LyBuf Nothing) []) IM.empty } 
                npages = IM.insert totalnumofpages npage pgs 
                newtxoj = txoj { gselectAll = npages } 
                xstate' = set xournalstate (SelectState newtxoj) xstate
            commit xstate'
            return (xstate',newtxoj,npages,totalnumofpages+1,totalnumofpages)
          else if modifyfn oldpage < 0 
                 then return (xstate,txoj,pgs,totalnumofpages,0)
                 else return (xstate,txoj,pgs,totalnumofpages,modifyfn oldpage)
        let Dim w h = gdimension lpage
            (hadj,vadj) = get adjustments currCvsInfo
        liftIO $ do 
          adjustmentSetUpper hadj w 
          adjustmentSetUpper vadj h 
          adjustmentSetValue hadj 0
          adjustmentSetValue vadj 0
        let currCvsInfo' = setPage (SelectState txoj') newpage currCvsInfo 
            xstate'' = updatePageAll (SelectState txoj')
                       . updateCanvasInfo currCvsInfo' 
                       $ xstate'
        putSt xstate'' 
        invalidate currCvsId 
      
canvasZoomUpdate :: Maybe ZoomMode -> CanvasId -> Iteratee MyEvent XournalStateIO ()
canvasZoomUpdate mzmode cid = do 
    xstate <- getSt 
    let cinfoMap = get canvasInfoMap xstate
    case IM.lookup cid cinfoMap of 
      Nothing -> do
        liftIO $ putStrLn $ "canvasZoomUpdate : no cid = " ++ show cid 
        return () 
      Just cvsInfo -> do 
        let zmode = maybe (get (zoomMode.viewInfo) cvsInfo) id mzmode
        let canvas = get drawArea cvsInfo
        let page = getPage cvsInfo 
        let Dim w h = gdimension page
        cpg <- liftIO (getCanvasPageGeometry canvas page (0,0))        
        let (w',h') = canvas_size cpg 
        let (hadj,vadj) = get adjustments cvsInfo 
            s = 1.0 / getRatioFromPageToCanvas cpg zmode
        liftIO $ setAdjustments (hadj,vadj) (w,h) (0,0) (0,0) (w'*s,h'*s)
        let cvsInfo' = set (zoomMode.viewInfo) zmode
                       . set (viewPortOrigin.viewInfo) (0,0)
                       $ cvsInfo 
            xstate' = updateCanvasInfo cvsInfo' xstate
        putSt xstate' 
        invalidate cid       


pageZoomChange :: ZoomMode -> Iteratee MyEvent XournalStateIO () 
pageZoomChange zmode = do 
    xstate <- getSt 
    let currCvsId = get currentCanvas xstate
    canvasZoomUpdate (Just zmode) currCvsId         

newPageBefore :: Iteratee MyEvent XournalStateIO () 
newPageBefore = do 
  liftIO $ putStrLn "newPageBefore called"
  xstate <- getSt
  let xojstate = get xournalstate xstate
  case xojstate of 
    ViewAppendState xoj -> do 
      liftIO $ putStrLn " In View " 
      let currCvsId = get currentCanvas xstate 
          mcurrCvsInfo = IM.lookup currCvsId (get canvasInfoMap xstate)
      xoj' <- maybe (error $ "something wrong in newPageBefore")
                    (liftIO . newPageBeforeAction xoj)
                    $ (,) <$> pure currCvsId <*> mcurrCvsInfo  
      let xstate' = updatePageAll (ViewAppendState xoj')
                    . set xournalstate  (ViewAppendState xoj') 
                    $ xstate 
      commit xstate'
      invalidate currCvsId 
    SelectState txoj -> liftIO $ putStrLn " In Select State, this is not implemented yet."

