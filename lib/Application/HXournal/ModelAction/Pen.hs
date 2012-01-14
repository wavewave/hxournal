{-# LANGUAGE OverloadedStrings #-}

module Application.HXournal.ModelAction.Pen where

import Application.HXournal.Accessor
import Application.HXournal.ModelAction.Page
import Application.HXournal.ModelAction.Layer
import Application.HXournal.Type.Canvas
import Application.HXournal.Type.Enum
import Data.Foldable
import Data.Maybe
import qualified Data.Map as M
import qualified Data.IntMap as IM
import Control.Category
import Data.Sequence hiding (take, drop)
import Data.Label
import Prelude hiding ((.), id)
import Data.Strict.Tuple hiding (uncurry)
import Data.Xournal.Simple
import Data.Xournal.Generic
import Data.Xournal.BBox
import Data.Xournal.Select 

import Graphics.Xournal.Render.BBoxMapPDF

addPDraw :: PenInfo -> TXournalBBoxMapPDFBuf -> Int -> Seq (Double,Double) 
            -> IO (TXournalBBoxMapPDFBuf,BBox)
addPDraw pinfo xoj pgnum pdraw = do 
  let pcolor = get penColor pinfo
      pcolname = fromJust (M.lookup pcolor penColorNameMap)
      pwidth = get penWidth pinfo
      (mcurrlayer,currpage) = getCurrentLayerOrSet (getPageFromGXournalMap pgnum xoj)
      currlayer = maybe (error "something wrong in addPDraw") id mcurrlayer 

      newstroke = Stroke { stroke_tool = "pen" 
                         , stroke_color = pcolname 
                         , stroke_width = pwidth
                         , stroke_data = map (uncurry (:!:)) . toList $ pdraw
                         } 
      newstrokebbox = mkStrokeBBoxFromStroke newstroke
      bbox = strokebbox_bbox newstrokebbox
  newlayerbbox <- updateLayerBuf (Just bbox)
                   . set g_bstrokes (get g_bstrokes currlayer ++ [newstrokebbox]) 
                   $ currlayer
  let newpagebbox = adjustCurrentLayer newlayerbbox currpage
      newxojbbox = set g_pages (IM.adjust (const newpagebbox) pgnum (get g_pages xoj) ) xoj 
  return (newxojbbox,bbox) 










