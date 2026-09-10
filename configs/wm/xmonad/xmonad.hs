
import System.Exit (exitSuccess)
import XMonad
import XMonad.Actions.Navigation2D
import XMonad.Hooks.EwmhDesktops (ewmh)
import XMonad.Layout.MultiToggle (Toggle (..), mkToggle, single)
import XMonad.Layout.MultiToggle.Instances (StdTransformers (FULL))
import XMonad.Util.EZConfig (additionalKeys, removeKeys)
import XMonad.Util.SpawnOnce (spawnOnce)
import qualified Data.Map as M
import qualified XMonad.StackSet as W

main :: IO ()
main = xmonad $ ewmh $ withNavigation2DConfig def myConfig

myWorkspaces :: [String]
myWorkspaces = map show [1 .. 9 :: Int]

myConfig = def
    { terminal           = "@TERM@"
    , modMask            = mod4Mask
    , workspaces         = myWorkspaces
    , borderWidth        = 1
    , normalBorderColor  = "#2a2a2a"
    , focusedBorderColor = "#4a4a4a"
    , focusFollowsMouse  = False
    , layoutHook         = myLayout
    , startupHook        = spawnOnce "~/.config/ibr/autostart"
    }
    `removeKeys` stockKeys
    `additionalKeys` myKeys

myLayout = mkToggle (single FULL) (tall ||| Mirror tall)
  where
    tall = Tall 1 (3 / 100) (1 / 2)

stockKeys :: [(KeyMask, KeySym)]
stockKeys =
    [ (mod4Mask, xK_p)
    , (mod4Mask .|. shiftMask, xK_p)
    , (mod4Mask .|. shiftMask, xK_Return)
    ]

myKeys :: [((KeyMask, KeySym), X ())]
myKeys =
    [ ((mod4Mask, xK_Return), spawn "@TERM@")
    , ((mod4Mask, xK_d), spawn "@MENU@")
    , ((mod4Mask .|. shiftMask, xK_q), kill)
    , ((mod4Mask, xK_f), sendMessage $ Toggle FULL)
    , ((mod4Mask .|. shiftMask, xK_space), withFocused toggleFloat)
    , ((mod4Mask .|. shiftMask, xK_c), spawn "xmonad --recompile && xmonad --restart")
    , ((mod4Mask .|. shiftMask, xK_e), io exitSuccess)
    , ((mod4Mask, xK_h), windowGo L False)
    , ((mod4Mask, xK_j), windowGo D False)
    , ((mod4Mask, xK_k), windowGo U False)
    , ((mod4Mask, xK_l), windowGo R False)
    , ((mod4Mask .|. shiftMask, xK_h), windowSwap L False)
    , ((mod4Mask .|. shiftMask, xK_j), windowSwap D False)
    , ((mod4Mask .|. shiftMask, xK_k), windowSwap U False)
    , ((mod4Mask .|. shiftMask, xK_l), windowSwap R False)
    , ((0, xK_Print), spawn "@SHOT@")
    ]
    ++ [ ((mod4Mask .|. m, k), windows $ f i)
       | (i, k) <- zip myWorkspaces [xK_1 .. xK_9]
       , (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]
       ]

toggleFloat :: Window -> X ()
toggleFloat w = windows $ \s ->
    if M.member w (W.floating s)
        then W.sink w s
        else W.float w (W.RationalRect (1 / 4) (1 / 4) (1 / 2) (1 / 2)) s
