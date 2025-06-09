{-# LANGUAGE OverloadedStrings #-}

import Hakyll

main :: IO ()
main = hakyllWith config $ do
    -- match "posts/*" $ do
    -- route $ setExtension "html"
    -- compile $
    -- pandocCompiler
    -- >>= loadAndApplyTemplate "templates/post.html" defaultContext
    -- >>= relativizeUrls

    -- match "templates/*" $ compile templateBodyCompiler

    match "static/index.html" $ do
        route $ constRoute "index.html"
        compile copyFileCompiler

-- create ["index.html"] $ do
-- route idRoute
-- compile $ do
-- posts <- recentFirst =<< loadAll "posts/*"
-- let ctx = listField "posts" defaultContext (return posts) <> defaultContext
-- makeItem ""
-- >>= loadAndApplyTemplate "templates/index.html" ctx
-- >>= relativizeUrls

config :: Configuration
config = defaultConfiguration{destinationDirectory = "docs"}
