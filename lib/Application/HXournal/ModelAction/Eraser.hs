module Application.HXournal.ModelAction.Eraser where

import Control.Monad.State 

import Data.Xournal.BBox
import Graphics.Xournal.Render.Type 
import Graphics.Xournal.Render.HitTest

eraseHitted :: AlterList (NotHitted StrokeBBox) (AlterList (NotHitted StrokeBBox) (Hitted StrokeBBox)) 
               -> State (Maybe BBox) [StrokeBBox]
eraseHitted Empty = error "something wrong in eraseHitted"
eraseHitted (n :-Empty) = return (unNotHitted n)
eraseHitted (n:-h:-rest) = do 
  mid <- elimHitted h 
  return . (unNotHitted n ++) . (mid ++) =<< eraseHitted rest
