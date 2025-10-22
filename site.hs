{-# LANGUAGE OverloadedStrings #-}

import Hakyll

main :: IO ()
main = hakyllWith config $ do
    match "static/index.html" $ do
        route $ constRoute "index.html"
        compile copyFileCompiler

config :: Configuration
config = defaultConfiguration{destinationDirectory = "docs"}
