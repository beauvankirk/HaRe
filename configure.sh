#!/bin/sh

# This script is temporary until ghc-mod is fixed to reconfigure on change

# cabal clean && cabal configure  --enable-tests --disable-optimization

# # Make sure the tests run against the newly installed environment
# (cd test/testdata && cabal clean && cabal configure)

# (cd test/testdata/cabal/cabal1 && cabal clean && cabal configure)
# (cd test/testdata/cabal/cabal2 && cabal clean && cabal configure)
# (cd test/testdata/cabal/cabal3 && cabal clean && cabal configure)
# (cd test/testdata/cabal/cabal4 && cabal clean && cabal configure)
# (cd test/testdata/cabal/foo    && cabal clean && cabal configure)

rm .ghc.environment.*
# rm cabal.project.local
# rm -fr dist*



# cabal-2.2 new-configure --with-compiler=/opt/ghc/8.4.0.20180204/bin/ghc --allow-newer
# cabal new-configure --enable-tests --with-compiler=/opt/ghc/8.6.0.20180627/bin/ghc --allow-newer
# cabal new-configure --enable-tests --with-compiler=/opt/ghc/8.6.0.20180712/bin/ghc --allow-newer
# cabal-2.4 new-configure --enable-tests --with-compiler=/opt/ghc/8.6.0.20180810/bin/ghc --allow-newer
# cabal new-configure --enable-tests --with-compiler=/opt/ghc/8.6.0.20180810/bin/ghc --allow-newer

cabal-2.4 new-configure  --with-compiler=/opt/ghc/8.6.0.20180810/bin/ghc --allow-newer
