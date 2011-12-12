module Application.HXournal.ModelAction.File where

import Application.HXournal.Type.XournalState
import Application.HXournal.Type.Canvas
import Application.HXournal.ModelAction.Page
import Graphics.Xournal.Type.Map
import Text.Xournal.Type
import qualified Text.Xournal.Parse as P
import qualified Data.IntMap as M
import Control.Category
import Data.Label
import Prelude hiding ((.),id)

-- | get file content from xournal file and update xournal state 

getFileContent :: Maybe FilePath 
               -> HXournalState 
               -> IO HXournalState 
getFileContent (Just fname) xstate = do 
    xojcontent <- P.read_xournal fname 
    let currcid = get currentCanvas xstate 
        cmap = get canvasInfoMap xstate 
    let xojWbbox = mkXournalBBoxMapFromXournal xojcontent 
    let Dim width height = pageDim . (!! 0) .  xournalPages $ xojcontent
        startingxojstate = ViewAppendState xojWbbox
        cids = M.keys cmap 
        update x _cinfo = 
          let changefunc c = 
                setPage startingxojstate 0 
                . set viewInfo (ViewInfo OnePage Original (0,0) (width,height))
                . set currentPageNum 0 
                $ c 
          in  M.adjust changefunc x cmap  
        cmap' = foldr update cmap cids   
    let newxstate = set xournalstate startingxojstate
                    . set currFileName (Just fname)
                    . set canvasInfoMap cmap'
                    . set currentCanvas currcid 
                    $ xstate
    return newxstate 
getFileContent Nothing xstate = do   
    let newxoj = mkXournalBBoxMapFromXournal defaultXournal 
        newxojstate = ViewAppendState newxoj 
        xstate' = set currFileName Nothing 
                  . set xournalstate newxojstate
                  $ xstate 
        cmap = get canvasInfoMap xstate'
    let Dim w h = pageDim . (!! 0) .  xournalPages $ defaultXournal
        ciupdt = setPage newxojstate 0                       
                 . set viewInfo (ViewInfo OnePage Original (0,0) (w,h))
                 . set currentPageNum 0 
        cmap' = M.map ciupdt cmap
    return (set canvasInfoMap cmap' xstate')
