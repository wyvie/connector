import System.Environment
import UI.NCurses
import qualified Dns as D
import qualified NGram as N
import Data.Char(ord)
import System.Process

data Args = Args {window :: Window, input :: String, hosts :: [N.Host]}

inviteString = "Enter ur stuff: "
allowedInput = ['a'..'z'] ++ ['0'..'9'] ++ ['-', '.']

showResult :: Window -> Integer -> String -> [N.Host] -> Curses (Maybe N.Host)
showResult w selection input hosts = do
    (rows, cols) <- screenSize
    let closeHosts = N.findCloseHosts input hosts
    updateWindow w $ do
        if (length input) > 2
        then do
            clearHosts w rows cols
            drawHosts selection (take (fromIntegral (rows-1)) closeHosts) 1
        else return ()
        moveCursor 0 0
        drawString $ replicate (fromIntegral (rows-1)) ' '
        moveCursor 0 0
        drawString $ inviteString ++ input
    render
    getInput w selection input closeHosts

getHost :: Integer -> [N.Host] -> N.Host
getHost sel hosts =
    if sel == 0
    then head hosts
    else hosts !! (fromIntegral $ sel - 1)

reactOnCharacter :: Window -> Integer -> Char -> String -> [N.Host] -> Curses (Maybe N.Host)
reactOnCharacter w selection c input hosts =
    if elem c $ allowedInput
    then showResult w 0 (input ++ [c]) hosts
    else if (ord c) == 10
        then do
            return $ Just $ getHost selection hosts
        else if (ord c) == 27
             then return Nothing
             else getInput w 0 input hosts

delChar :: String -> String
delChar [] = []
delChar x = init x

decSel :: Integer -> Integer -> Integer
decSel rows cur =
    if cur-1 <= 0
    then 1
    else cur - 1

incSel :: Integer -> Integer -> Integer
incSel rows cur =
    if cur+1 == rows
    then cur
    else cur+1

reactOnKey :: Window -> Integer -> Key -> String -> [N.Host] -> Curses (Maybe N.Host)
reactOnKey w selection k input hosts = do
    (rows, _) <- screenSize
    case k of KeyBackspace -> showResult w 0 (delChar input) hosts
              KeyUpArrow -> showResult w (decSel rows selection) input hosts
              KeyDownArrow -> showResult w (incSel rows selection) input hosts
              _ -> getInput w selection input hosts

reactOnEvent ::	Window -> Integer -> Event -> String -> [N.Host] -> Curses (Maybe N.Host)
reactOnEvent w selection ev input hosts =
    case ev of EventCharacter c -> reactOnCharacter w selection c input hosts
               EventSpecialKey key -> reactOnKey w selection key input hosts

getInput :: Window -> Integer -> String -> [N.Host] -> Curses (Maybe N.Host)
getInput w selection curInput hosts = loop where
    loop = do
        ev <- getEvent w Nothing
        case ev of
            Nothing -> loop
            Just ev' -> reactOnEvent w selection ev' curInput hosts

clearHostLines :: Integer -> Integer -> Integer -> Update ()
clearHostLines curRow rows columns = do
    if (curRow+1) == rows
    then return ()
    else do
        moveCursor curRow 0
        drawString $ take (fromIntegral columns) $ repeat ' '
        clearHostLines (curRow+1) rows columns

clearHosts :: Window -> Integer -> Integer -> Update ()
clearHosts w rows cols = do
    clearHostLines 1 rows cols

drawHosts :: Integer ->[N.Host] -> Integer -> Update ()
drawHosts _ [] _ = return ()
drawHosts selection (host:other) line = do
    moveCursor line 3
    drawString $ show host
    if selection == line
    then do
        moveCursor line 0
        drawString "*"
    else return ()
    drawHosts selection other (line+1)

goIntoCurses :: [N.Host] -> IO (Maybe N.Host)
goIntoCurses hosts = runCurses $ do
    setEcho False
    w <- defaultWindow
    updateWindow w $ do
        moveCursor 0 0
        drawString inviteString
    render
    host <- getInput w 0 "" hosts
    return host

runSsh :: String -> N.Host -> IO ()
runSsh login host = do
    code <- system $ "ssh " ++ login ++ "@" ++ (head $ N.names host)
    return ()
	
main :: IO ()
main = do
    (fileName:login:_) <- getArgs
    lines <- D.parse fileName
    host <- goIntoCurses $ map (N.createHost . (:[])) lines
    case host of Nothing -> return ()
                 Just value -> runSsh login value
    return ()