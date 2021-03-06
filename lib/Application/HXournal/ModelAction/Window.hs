{-# LANGUAGE ScopedTypeVariables #-}

-----------------------------------------------------------------------------
-- |
-- Module      : Application.HXournal.ModelAction.Window 
-- Copyright   : (c) 2011, 2012 Ian-Woo Kim
--
-- License     : BSD3
-- Maintainer  : Ian-Woo Kim <ianwookim@gmail.com>
-- Stability   : experimental
-- Portability : GHC
--
-----------------------------------------------------------------------------

module Application.HXournal.ModelAction.Window where

import Application.HXournal.Type.Canvas
import Application.HXournal.Type.Event
import Application.HXournal.Type.PageArrangement
import Application.HXournal.Type.Window
import Application.HXournal.Type.XournalState
import Application.HXournal.Device
import Application.HXournal.Util
import Graphics.UI.Gtk hiding (get,set)
import qualified Graphics.UI.Gtk as Gtk (set)
import Control.Monad.Trans 
import Control.Category
import Data.Label
import Prelude hiding ((.),id)
import qualified Data.IntMap as M
import System.FilePath

-- | set frame title according to file name

setTitleFromFileName :: HXournalState -> IO () 
setTitleFromFileName xstate = do 
  case get currFileName xstate of
    Nothing -> Gtk.set (get rootOfRootWindow xstate) 
                       [ windowTitle := "untitled" ]
    Just filename -> Gtk.set (get rootOfRootWindow xstate) 
                             [ windowTitle := takeFileName filename] 

-- | 

newCanvasId :: CanvasInfoMap -> CanvasId 
newCanvasId cmap = 
  let cids = M.keys cmap 
  in  (maximum cids) + 1  

-- | initialize CanvasInfo with creating windows and connect events

initCanvasInfo :: ViewMode a => HXournalState -> CanvasId -> IO (CanvasInfo a)
initCanvasInfo xstate cid = 
  minimalCanvasInfo xstate cid >>= connectDefaultEventCanvasInfo xstate
  

-- | only creating windows 

minimalCanvasInfo :: ViewMode a => HXournalState -> CanvasId -> IO (CanvasInfo a)
minimalCanvasInfo _xstate cid = do 
    canvas <- drawingAreaNew
    scrwin <- scrolledWindowNew Nothing Nothing 
    containerAdd scrwin canvas
    hadj <- adjustmentNew 0 0 500 100 200 200 
    vadj <- adjustmentNew 0 0 500 100 200 200 
    scrolledWindowSetHAdjustment scrwin hadj 
    scrolledWindowSetVAdjustment scrwin vadj 
    -- scrolledWindowSetPolicy scrwin PolicyAutomatic PolicyAutomatic 
    return $ CanvasInfo cid canvas scrwin (error "no viewInfo" :: ViewInfo a) 0 hadj vadj Nothing Nothing


-- | only connect events 

connectDefaultEventCanvasInfo :: ViewMode a =>  
                                 HXournalState -> CanvasInfo a -> IO (CanvasInfo a )
connectDefaultEventCanvasInfo xstate cinfo = do 
    let callback = get callBack xstate
        dev = get deviceList xstate 
        canvas = _drawArea cinfo 
        cid = _canvasId cinfo 
        scrwin = _scrolledWindow cinfo
        hadj = _horizAdjustment cinfo 
        vadj = _vertAdjustment cinfo 

    _sizereq <- canvas `on` sizeRequest $ return (Requisition 800 400)    
    
    _bpevent <- canvas `on` buttonPressEvent $ tryEvent $ do 
                 (mbtn,p) <- getPointer dev
                 let pbtn = maybe PenButton1 id mbtn
                 liftIO (callback (PenDown cid pbtn p))
    _confevent <- canvas `on` configureEvent $ tryEvent $ do 
                   (w,h) <- eventSize 
                   liftIO $ callback 
                     (CanvasConfigure cid (fromIntegral w) (fromIntegral h))
    _brevent <- canvas `on` buttonReleaseEvent $ tryEvent $ do 
                 (_,p) <- getPointer dev
                 liftIO (callback (PenUp cid p))
    _exposeev <- canvas `on` exposeEvent $ tryEvent $ do 
                  liftIO $ callback (UpdateCanvas cid) 

    {-
    canvas `on` enterNotifyEvent $ tryEvent $ do 
      win <- liftIO $ widgetGetDrawWindow canvas
      liftIO $ drawWindowSetCursor win (Just cursorDot)
      return ()
    -}  
    widgetAddEvents canvas [PointerMotionMask,Button1MotionMask]      
    let ui = get gtkUIManager xstate 
    agr <- liftIO ( uiManagerGetActionGroups ui >>= \x ->
                      case x of 
                        [] -> error "No action group? "
                        y:_ -> return y )
    uxinputa <- liftIO (actionGroupGetAction agr "UXINPUTA" >>= \(Just x) -> 
                          return (castToToggleAction x) )
    b <- liftIO $ toggleActionGetActive uxinputa
    if b then widgetSetExtensionEvents canvas [ExtensionEventsAll]
         else widgetSetExtensionEvents canvas [ExtensionEventsNone]
    hadjconnid <- afterValueChanged hadj $ do 
                    v <- adjustmentGetValue hadj 
                    callback (HScrollBarMoved cid v)
    vadjconnid <- afterValueChanged vadj $ do 
                    v <- adjustmentGetValue vadj     
                    callback (VScrollBarMoved cid v)
    Just vscrbar <- scrolledWindowGetVScrollbar scrwin
    _bpevtvscrbar <- vscrbar `on` buttonPressEvent $ do 
                      v <- liftIO $ adjustmentGetValue vadj 
                      liftIO (callback (VScrollBarStart cid v))
                      return False
    _brevtvscrbar <- vscrbar `on` buttonReleaseEvent $ do 
                      v <- liftIO $ adjustmentGetValue vadj 
                      liftIO (callback (VScrollBarEnd cid v))
                      return False
    return $ cinfo { _horizAdjConnId = Just hadjconnid
                   , _vertAdjConnId = Just vadjconnid }
    
-- | recreate windows from old canvas info but no event connect

reinitCanvasInfoStage1 :: (ViewMode a) => 
                           HXournalState 
                           ->  CanvasInfo a -> IO (CanvasInfo a)
reinitCanvasInfoStage1 xstate oldcinfo = do 
  let cid = get canvasId oldcinfo 
  newcinfo <- minimalCanvasInfo xstate cid      
  return $ newcinfo { _viewInfo = _viewInfo oldcinfo 
                    , _currentPageNum = _currentPageNum oldcinfo 
                    } 

    
-- | event connect

reinitCanvasInfoStage2 :: (ViewMode a) => 
                           HXournalState -> CanvasInfo a -> IO (CanvasInfo a)
reinitCanvasInfoStage2 = connectDefaultEventCanvasInfo
    
-- | event connecting for all windows                          
                         
eventConnect :: HXournalState -> WindowConfig 
                -> IO (HXournalState,WindowConfig)
eventConnect xstate (Node cid) = do 
    let cmap = getCanvasInfoMap xstate 
        cinfobox = maybeError "eventConnect" $ M.lookup cid cmap
    case cinfobox of       
      CanvasInfoBox cinfo -> do 
        ncinfo <- reinitCanvasInfoStage2 xstate cinfo 
        let xstate' = updateFromCanvasInfoAsCurrentCanvas (CanvasInfoBox ncinfo) xstate
        return (xstate', Node cid)
eventConnect xstate (HSplit wconf1 wconf2) = do  
    (xstate',wconf1') <- eventConnect xstate wconf1 
    (xstate'',wconf2') <- eventConnect xstate' wconf2 
    return (xstate'',HSplit wconf1' wconf2')
eventConnect xstate (VSplit wconf1 wconf2) = do  
    (xstate',wconf1') <- eventConnect xstate wconf1 
    (xstate'',wconf2') <- eventConnect xstate' wconf2 
    return (xstate'',VSplit wconf1' wconf2')
    


-- | default construct frame     

constructFrame :: HXournalState -> WindowConfig 
                  -> IO (HXournalState,Widget,WindowConfig)
constructFrame = constructFrame' (CanvasInfoBox defaultCvsInfoSinglePage)



-- | construct frames with template

constructFrame' :: CanvasInfoBox -> 
                   HXournalState -> WindowConfig 
                   -> IO (HXournalState,Widget,WindowConfig)
constructFrame' template oxstate (Node cid) = do 
    let ocmap = getCanvasInfoMap oxstate 
    (cinfobox,_cmap,xstate) <- case M.lookup cid ocmap of 
      Just cinfobox' -> return (cinfobox',ocmap,oxstate)
      Nothing -> do 
        let cinfobox' = setCanvasId cid template 
            cmap' = M.insert cid cinfobox' ocmap
            xstate' = maybe oxstate id (setCanvasInfoMap cmap' oxstate)
        return (cinfobox',cmap',xstate')
    case cinfobox of       
      CanvasInfoBox cinfo -> do 
        ncinfo <- reinitCanvasInfoStage1 xstate cinfo 
        let xstate' = updateFromCanvasInfoAsCurrentCanvas (CanvasInfoBox ncinfo) xstate
        return (xstate', castToWidget . get scrolledWindow $ ncinfo, Node cid)
constructFrame' template xstate (HSplit wconf1 wconf2) = do  
    (xstate',win1,wconf1') <- constructFrame' template xstate wconf1     
    (xstate'',win2,wconf2') <- constructFrame' template xstate' wconf2 
    let callback = get callBack xstate'' 
    hpane' <- hPanedNew
    hpane' `on` buttonPressEvent $ do 
      liftIO (callback PaneMoveStart)
      return False 
    hpane' `on` buttonReleaseEvent $ do 
      liftIO (callback PaneMoveEnd)
      return False       
    panedPack1 hpane' win1 True False
    panedPack2 hpane' win2 True False
    widgetShowAll hpane' 
    return (xstate'',castToWidget hpane', HSplit wconf1' wconf2')
constructFrame' template xstate (VSplit wconf1 wconf2) = do  
    (xstate',win1,wconf1') <- constructFrame' template xstate wconf1 
    (xstate'',win2,wconf2') <- constructFrame' template xstate' wconf2 
    let callback = get callBack xstate''     
    vpane' <- vPanedNew 
    vpane' `on` buttonPressEvent $ do 
      liftIO (callback PaneMoveStart)
      return False 
    vpane' `on` buttonReleaseEvent $ do 
      liftIO (callback PaneMoveEnd)
      return False 
    panedPack1 vpane' win1 True False
    panedPack2 vpane' win2 True False
    widgetShowAll vpane' 
    return (xstate'',castToWidget vpane', VSplit wconf1' wconf2')
  


