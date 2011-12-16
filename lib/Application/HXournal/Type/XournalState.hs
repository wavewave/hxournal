{-# LANGUAGE OverloadedStrings, TemplateHaskell #-}

module Application.HXournal.Type.XournalState where

import Application.HXournal.Device
import Application.HXournal.Type.Event 
import Application.HXournal.Type.Enum
import Application.HXournal.Type.Canvas
import Application.HXournal.Type.Clipboard
import Application.HXournal.Type.Window 

-- import Graphics.Xournal.Render.Select
import Data.Xournal.Map

import Graphics.Xournal.Render.BBoxMapPDF

import Control.Monad.State
import Data.Xournal.Simple
import Data.Xournal.Predefined 
import Graphics.UI.Gtk hiding (Clipboard)
import Data.Maybe
import Data.Label 
import Prelude hiding ((.), id)

type XournalStateIO = StateT HXournalState IO 

data XournalState = ViewAppendState { unView :: TXournalBBoxMapPDF }
                  | SelectState { tempSelect :: TTempXournalSelectPDF }

data HXournalState = HXournalState { _xournalstate :: XournalState
                                   , _currFileName :: Maybe FilePath
                                   , _canvasInfoMap :: CanvasInfoMap 
                                   , _currentCanvas :: Int
                                   , _frameState :: WindowConfig 
                                   , _rootWindow :: Widget
                                   , _rootContainer :: Box
                                   , _rootOfRootWindow :: Window
                                   , _currentPenDraw :: PenDraw
                                   , _clipboard :: Clipboard
                                   , _callBack ::  MyEvent -> IO ()
                                   , _deviceList :: DeviceList
                                   , _penInfo :: PenInfo
                                   , _selectInfo :: SelectInfo 
                                   , _gtkUIManager :: UIManager 
                                   } 


$(mkLabels [''HXournalState]) 

emptyHXournalState :: HXournalState 
emptyHXournalState = 
  HXournalState  
  { _xournalstate = ViewAppendState emptyTXournalBBoxMapPDF
                    -- (mkXournalBBoxMapFromXournal emptyXournal)
  , _currFileName = Nothing 
  , _canvasInfoMap = error "emptyHXournalState.canvasInfoMap"
  , _currentCanvas = error "emtpyHxournalState.currentCanvas"
  , _frameState = error "emptyHXournalState.frameState" 
  , _rootWindow = error "emtpyHXournalState.rootWindow"
  , _rootContainer = error "emptyHXournalState.rootContainer"
  , _rootOfRootWindow = error "emptyHXournalState.rootOfRootWindow"
  , _currentPenDraw = emptyPenDraw 
  , _clipboard = emptyClipboard
  , _callBack = error "emtpyHxournalState.callBack"
  , _deviceList = error "emtpyHxournalState.deviceList"
  , _penInfo = PenInfo PenWork predefined_medium ColorBlack
  , _selectInfo = SelectInfo SelectRectangleWork 
  , _gtkUIManager = error "emptyHXournalState.gtkUIManager"
  }

  
