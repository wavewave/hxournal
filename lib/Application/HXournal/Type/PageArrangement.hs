{-# LANGUAGE EmptyDataDecls, GADTs, TypeOperators, GeneralizedNewtypeDeriving #-}

-----------------------------------------------------------------------------
-- |
-- Module      : Application.HXournal.Type.PageArrangement
-- Copyright   : (c) 2012 Ian-Woo Kim
--
-- License     : BSD3
-- Maintainer  : Ian-Woo Kim <ianwookim@gmail.com>
-- Stability   : experimental
-- Portability : GHC
--
-----------------------------------------------------------------------------

module Application.HXournal.Type.PageArrangement where

import Control.Category ((.))
import Data.Xournal.Simple (Dimension(..))
import Data.Xournal.Generic
import Data.Xournal.BBox
import Data.Label 
import Prelude hiding ((.),id)
-- import qualified Data.IntMap as M

import Application.HXournal.Type.Alias

data PageMode = Continous | OnePage
              deriving (Show,Eq) 

data ZoomMode = Original | FitWidth | FitHeight | Zoom Double 
              deriving (Show,Eq)

class ViewMode a 

data SinglePage = SinglePage
data ContinuousSinglePage = ContinuousSinglePage

instance ViewMode SinglePage 
instance ViewMode ContinuousSinglePage

newtype PageNum = PageNum { unPageNum :: Int } 
                deriving (Eq,Show,Ord,Num)

newtype ScreenDimension = ScreenDimension { unScreenDimension :: Dimension } 
newtype CanvasDimension = CanvasDimension { unCanvasDimension :: Dimension }
newtype CanvasOrigin = CanvasOrigin { unCanvasOrigin :: (Double,Double) } 
newtype PageOrigin = PageOrigin { unPageOrigin :: (Double,Double) } 
newtype PageDimension = PageDimension { unPageDimension :: Dimension } 
newtype DesktopDimension = DesktopDimension { unDesktopDimension :: Dimension }
newtype ViewPortBBox = ViewPortBBox { unViewPortBBox :: BBox } 

                     
apply :: (BBox -> BBox) -> ViewPortBBox -> ViewPortBBox 
apply f (ViewPortBBox bbox1) = ViewPortBBox (f bbox1)
{-# INLINE apply #-}

-- | data structure for coordinate arrangement of pages in desktop coordinate

data PageArrangement a where
  SingleArrangement:: PageDimension 
                      -> ViewPortBBox 
                      -> PageArrangement SinglePage 
  ContinuousSingleArrangement :: DesktopDimension 
                                 -> (Xournal EditMode -> PageNum -> PageOrigin) 
                                 -> ViewPortBBox -> PageArrangement ContinuousSinglePage

-- | 

pageArrEither :: PageArrangement a 
                 -> Either (PageArrangement SinglePage) (PageArrangement ContinuousSinglePage)
pageArrEither arr@(SingleArrangement _ _) = Left arr 
pageArrEither arr@(ContinuousSingleArrangement _ _ _) = Right arr 

-- |

getRatioPageCanvas :: ZoomMode -> PageDimension -> CanvasDimension -> (Double,Double)
getRatioPageCanvas zmode (PageDimension (Dim w h)) (CanvasDimension (Dim w' h')) = 
  case zmode of 
    Original -> (1.0,1.0)
    FitWidth -> (w'/w,w'/w)
    FitHeight -> (h'/h,h'/h)
    Zoom s -> (s,s)

-- |

makeSingleArrangement :: ZoomMode -> PageDimension -> CanvasDimension 
                         -> PageArrangement SinglePage
makeSingleArrangement zmode pdim cdim@(CanvasDimension (Dim w' h')) = 
  let (sinvx,sinvy) = getRatioPageCanvas zmode pdim cdim
      bbox = BBox (0,0) (w'/sinvx,h'/sinvy)
  in SingleArrangement pdim (ViewPortBBox bbox) 

-- | 

makeContinousSingleArrangement :: ZoomMode -> CanvasDimension -> Xournal EditMode -> PageNum 
                                  -> PageArrangement ContinuousSinglePage
makeContinousSingleArrangement zmode cdim@(CanvasDimension (Dim cw ch)) xoj pnum = 
  let PageOrigin (_,y0) = pageArrFuncContSingle xoj pnum 
      dim@(Dim pw ph) = get g_dimension . head . gToList . get g_pages $ xoj
      (sinvx,sinvy) = getRatioPageCanvas zmode (PageDimension dim) cdim 
      vport = ViewPortBBox (BBox (0,y0) (cw/sinvx,y0+ch/sinvy))
  in ContinuousSingleArrangement (deskDimContSingle xoj) pageArrFuncContSingle vport 

-- |

pageArrFuncContSingle :: Xournal EditMode -> PageNum -> PageOrigin 
pageArrFuncContSingle xoj pnum@(PageNum n) = PageOrigin (0,y)
  where addf x y = x + y + 20 
        y = foldr1 addf . take n . map (dim_height.get g_dimension) . gToList . get g_pages 
            $ xoj 
        

deskDimContSingle :: Xournal EditMode -> DesktopDimension 
deskDimContSingle xoj = 
  let PageOrigin (_,h) = pageArrFuncContSingle xoj (PageNum . length . gToList . get g_pages $ xoj)
      w = maximum . map (dim_width.get g_dimension) . gToList . get g_pages $ xoj
  in DesktopDimension (Dim w h)

-- lenses

pageDimension :: PageArrangement SinglePage :-> PageDimension
pageDimension = lens getter setter 
  where getter (SingleArrangement pdim _) = pdim
        setter pdim (SingleArrangement _ vbbox) = SingleArrangement pdim vbbox

viewPortBBox :: PageArrangement a :-> ViewPortBBox 
viewPortBBox = lens getter setter 
  where getter (SingleArrangement _ vbbox) = vbbox 
        getter (ContinuousSingleArrangement _ _ vbbox) = vbbox 
        setter vbbox (SingleArrangement pdim _) = SingleArrangement pdim vbbox 
        setter vbbox (ContinuousSingleArrangement ddim pfunc _) = ContinuousSingleArrangement ddim pfunc vbbox

desktopDimension :: PageArrangement a :-> DesktopDimension 
desktopDimension = lens getter (error "setter for desktopDimension is not defined")
  where getter (SingleArrangement (PageDimension dim) _) = DesktopDimension dim
        getter (ContinuousSingleArrangement ddim _ _) = ddim 





