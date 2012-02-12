{-# LANGUAGE GADTs #-}

-----------------------------------------------------------------------------
-- |
-- Module      : Application.HXournal.View.Coordinate
-- Copyright   : (c) 2012 Ian-Woo Kim
--
-- License     : BSD3
-- Maintainer  : Ian-Woo Kim <ianwookim@gmail.com>
-- Stability   : experimental
-- Portability : GHC
--
-----------------------------------------------------------------------------

module Application.HXournal.View.Coordinate where 

import Graphics.UI.Gtk hiding (get,set)
import Control.Applicative
import Control.Category
import Data.Label 
import Prelude hiding ((.),id)
import qualified Data.IntMap as M
import Data.Maybe
import Data.Monoid
import Data.Xournal.Simple (Dimension(..))
import Data.Xournal.Generic
import Data.Xournal.BBox 
-- import Graphics.Xournal.Render.HitTest
import Application.HXournal.Device
import Application.HXournal.Type.Canvas
import Application.HXournal.Type.PageArrangement
import Application.HXournal.Type.Alias

-- | data structure for transformation among screen, canvas, desktop and page coordinates

data CanvasGeometry = 
  CanvasGeometry 
  { screenDim :: ScreenDimension
  , canvasDim :: CanvasDimension
  -- , canvasOrigin :: CanvasOrigin 
  , desktopDim :: DesktopDimension 
  , canvasViewPort :: ViewPortBBox -- ^ in desktop coordinate 
  , screen2Canvas :: ScreenCoordinate -> CanvasCoordinate
  , canvas2Screen :: CanvasCoordinate -> ScreenCoordinate
  , canvas2Desktop :: CanvasCoordinate -> DesktopCoordinate
  , desktop2Canvas :: DesktopCoordinate -> CanvasCoordinate
  , desktop2Page :: DesktopCoordinate -> Maybe (PageNum,PageCoordinate)
  , page2Desktop :: (PageNum,PageCoordinate) -> DesktopCoordinate
  } 

-- | make a canvas geometry data structure from current status 

makeCanvasGeometry :: -- (GPageable em) => 
                      -- em 
                      PageNum -- , Page em) -> PageDimension 
                      -> PageArrangement vm 
                      -> DrawingArea 
                      -> IO CanvasGeometry 
-- makeCanvasGeometry typ (cpn,page) arr canvas = do  
makeCanvasGeometry cpn arr canvas = do 
  win <- widgetGetDrawWindow canvas
  let cdim@(CanvasDimension (Dim w' h')) = get canvasDimension arr
  screen <- widgetGetScreen canvas
  (ws,hs) <- (,) <$> (fromIntegral <$> screenGetWidth screen)
                 <*> (fromIntegral <$> screenGetHeight screen)
  (x0,y0) <- return . ((,) <$> fromIntegral.fst <*> fromIntegral.snd ) =<< drawWindowGetOrigin win
  let -- (Dim w h) = get g_dimension page
      corig = CanvasOrigin (x0,y0)
  let (deskdim, cvsvbbox, p2d, d2p) = 
        case arr of  
          SingleArrangement _ pdim vbbox -> ( DesktopDimension . unPageDimension $ pdim
                                               , vbbox
                                               , DeskCoord . unPageCoord . snd
                                               , \(DeskCoord coord) ->Just (cpn,(PageCoord coord)) )
          ContinuousSingleArrangement _ ddim pfunc vbbox -> 
            ( ddim, vbbox, makePage2Desktop pfunc, makeDesktop2Page pfunc ) 
  let s2c = xformScreen2Canvas corig
      c2s = xformCanvas2Screen corig
      c2d = xformCanvas2Desk cdim cvsvbbox 
      d2c = xformDesk2Canvas cdim cvsvbbox
  return $ CanvasGeometry (ScreenDimension (Dim ws hs)) (CanvasDimension (Dim w' h')) 
                          deskdim cvsvbbox s2c c2s c2d d2c d2p p2d
    





-- |
 
makePage2Desktop :: (PageNum -> Maybe PageOrigin) 
                    -> (PageNum,PageCoordinate) -> DesktopCoordinate
makePage2Desktop pfunc (pnum,PageCoord (x,y)) = 
  maybe (DeskCoord (-100,-100)) (\(PageOrigin (x0,y0)) -> DeskCoord (x0+x,y0+y)) (pfunc pnum) 
     
-- | 

makeDesktop2Page :: (PageNum -> Maybe PageOrigin) -> DesktopCoordinate 
                    -> Maybe (PageNum, PageCoordinate)
makeDesktop2Page pfunc (DeskCoord (x,y)) =
  let (prev,_next) = break (y<) . map (snd.unPageOrigin) . catMaybes
                    . takeWhile isJust . map (pfunc.PageNum) $ [0..] 
  in Just (PageNum (length prev-1),PageCoord (x,y- last prev)) 

    
-- |   
  
xformScreen2Canvas :: CanvasOrigin -> ScreenCoordinate -> CanvasCoordinate
xformScreen2Canvas (CanvasOrigin (x0,y0)) (ScrCoord (sx,sy)) = CvsCoord (sx-x0,sy-y0)

-- |

xformCanvas2Screen :: CanvasOrigin -> CanvasCoordinate -> ScreenCoordinate 
xformCanvas2Screen (CanvasOrigin (x0,y0)) (CvsCoord (cx,cy)) = ScrCoord (cx+x0,cy+y0)

-- |

xformCanvas2Desk :: CanvasDimension -> ViewPortBBox -> CanvasCoordinate 
                    -> DesktopCoordinate 
xformCanvas2Desk (CanvasDimension (Dim w h)) (ViewPortBBox (BBox (x1,y1) (x2,y2))) 
                 (CvsCoord (cx,cy)) = DeskCoord (cx*(x2-x1)/w+x1,cy*(y2-y1)/h+y1) 

-- |

xformDesk2Canvas :: CanvasDimension -> ViewPortBBox -> DesktopCoordinate 
                    -> CanvasCoordinate
xformDesk2Canvas (CanvasDimension (Dim w h)) (ViewPortBBox (BBox (x1,y1) (x2,y2)))
                 (DeskCoord (dx,dy)) = CvsCoord ((dx-x1)*w/(x2-x1),(dy-y1)*h/(y2-y1))
                                       
-- | 

screen2Desktop :: CanvasGeometry -> ScreenCoordinate -> DesktopCoordinate
screen2Desktop geometry = canvas2Desktop geometry . screen2Canvas geometry  

-- | 

desktop2Screen :: CanvasGeometry -> DesktopCoordinate -> ScreenCoordinate
desktop2Screen geometry = canvas2Screen geometry . desktop2Canvas geometry

-- |

core2Desktop :: CanvasGeometry -> (Double,Double) -> DesktopCoordinate 
core2Desktop geometry = canvas2Desktop geometry . CvsCoord 

-- |

wacom2Desktop :: CanvasGeometry -> (Double,Double) -> DesktopCoordinate
wacom2Desktop geometry (x,y) = let Dim w h = unScreenDimension (screenDim geometry)
                               in screen2Desktop geometry . ScrCoord $ (w*x,h*y) 
                                  
wacom2Canvas :: CanvasGeometry -> (Double,Double) -> CanvasCoordinate                       
wacom2Canvas geometry (x,y) = let Dim w h = unScreenDimension (screenDim geometry)
                              in screen2Canvas geometry . ScrCoord $ (w*x,h*y) 
         

-- | 

device2Desktop :: CanvasGeometry -> PointerCoord -> DesktopCoordinate 
device2Desktop geometry (PointerCoord typ x y _z) =  
  case typ of 
    Core -> core2Desktop geometry (x,y)
    Stylus -> wacom2Desktop geometry (x,y)
    Eraser -> wacom2Desktop geometry (x,y)
device2Desktop _geometry NoPointerCoord = error "NoPointerCoordinate device2Desktop"
         
-- | 

getPagesInViewPortRange :: CanvasGeometry -> Xournal EditMode -> [PageNum]
getPagesInViewPortRange geometry xoj = 
  let ViewPortBBox bbox = canvasViewPort geometry
      ivbbox = Intersect (Middle bbox)
      pagemap = get g_pages xoj 
      pnums = map PageNum [ 0 .. (length . gToList $ pagemap)-1 ]
      pgcheck n pg = let Dim w h = get g_dimension pg  
                         DeskCoord ul = page2Desktop geometry (PageNum n,PageCoord (0,0)) 
                         DeskCoord lr = page2Desktop geometry (PageNum n,PageCoord (w,h))
                         -- nbbox = BBox ul lr 
                         inbbox = Intersect (Middle (BBox ul lr))
                         result = ivbbox `mappend` inbbox 
                     in case result of 
                          Intersect Bottom -> False 
                          _ -> True 
      f (PageNum n) = maybe False (pgcheck n) . M.lookup n $ pagemap 
  in filter f pnums

-- | 

getCvsGeomFrmCvsInfo :: (ViewMode a) => 
                        CanvasInfo a -> IO CanvasGeometry 
getCvsGeomFrmCvsInfo cinfo = do 
  let cpn = PageNum . get currentPageNum $ cinfo 
      canvas = get drawArea cinfo
      arr = get (pageArrangement.viewInfo) cinfo 
  makeCanvasGeometry cpn arr canvas 
  




