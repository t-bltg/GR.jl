# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
#
# Examples:
#   - env BINARYBUILDER_AUTOMATIC_APPLE=true julia build_tarballs.jl x86_64-apple-darwin14
#   - julia build_tarballs.jl x86_64-linux-gnu
#   - julia build_tarballs.jl x86_64-w64-mingw32
#
using BinaryBuilder

name = "GR"
version = v"0.71.8"

# Collection of sources required to complete build
sources = [
    GitSource("https://github.com/sciapp/gr.git", "933ff9c1c098dd21adc19d2b9cc680ae0d303071"),
    FileSource("https://github.com/sciapp/gr/releases/download/v$version/gr-$version.js",
               "7d664808838b1cec39a2107ef758d91c22cc8d4ff020e932cdc0754d6fc108f4", "gr.js")
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir/gr

if test -f "$prefix/lib/cmake/Qt5Gui/Qt5GuiConfigExtras.cmake"; then
    sed -i 's/_qt5gui_find_extra_libs.*AGL.framework.*//' $prefix/lib/cmake/Qt5Gui/Qt5GuiConfigExtras.cmake
fi

update_configure_scripts

make -C 3rdparty/qhull -j${nproc}

if [[ $target == *"mingw"* ]]; then
    winflags=-DCMAKE_C_FLAGS="-D_WIN32_WINNT=0x0f00"
    tifflags=-DTIFF_LIBRARY=${libdir}/libtiff-5.dll
else
    tifflags=-DTIFF_LIBRARY=${libdir}/libtiff.${dlext}
fi

if [[ "${target}" == *apple* ]]; then
    make -C 3rdparty/zeromq ZEROMQ_EXTRA_CONFIGURE_FLAGS="--host=${target}"
fi

if [[ "${target}" == arm-* ]]; then
    export CXXFLAGS="-Wl,-rpath-link,/opt/${target}/${target}/lib"
fi

mkdir build
cd build
cmake $winflags -DCMAKE_INSTALL_PREFIX=$prefix -DCMAKE_FIND_ROOT_PATH=$prefix -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} -DGR_USE_BUNDLED_LIBRARIES=ON $tifflags -DCMAKE_BUILD_TYPE=Release ..

VERBOSE=ON cmake --build . --config Release --target install -- -j${nproc}
cp ../../gr.js ${libdir}/

install_license $WORKSPACE/srcdir/gr/LICENSE.md

if [[ $target == *"apple-darwin"* ]]; then
    cd ${bindir}
    ln -s ../Applications/gksqt.app/Contents/MacOS/gksqt ./
    ln -s ../Applications/GKSTerm.app/Contents/MacOS/GKSTerm ./
fi
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [
    Platform("armv7l",  "linux"; libc="glibc"),
    Platform("aarch64", "linux"; libc="glibc"),
    Platform("x86_64",  "linux"; libc="glibc"),
    Platform("i686",  "linux"; libc="glibc"),
    Platform("powerpc64le",  "linux"; libc="glibc"),
    Platform("x86_64",  "windows"),
    Platform("i686",  "windows"),    
    Platform("x86_64",  "macos"),
    Platform("x86_64",  "freebsd"),
]
platforms = expand_cxxstring_abis(platforms)

# The products that we will ensure are always built
products = [
    LibraryProduct("libGR", :libGR, dont_dlopen=true),
    LibraryProduct("libGR3", :libGR3, dont_dlopen=true),
    LibraryProduct("libGRM", :libGRM, dont_dlopen=true),
    LibraryProduct("libGKS", :libGKS, dont_dlopen=true),
    ExecutableProduct("gksqt", :gksqt),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency("Bzip2_jll"),
    Dependency("Cairo_jll"),
    Dependency("FFMPEG_jll"),
    Dependency("Fontconfig_jll"),
    Dependency("GLFW_jll"),
    Dependency("JpegTurbo_jll"),
    Dependency("libpng_jll"),
    Dependency("Libtiff_jll"),
    Dependency("Pixman_jll"),
#    Dependency("Qhull_jll"),
    Dependency("Qt5Base_jll"),
    BuildDependency("Xorg_libX11_jll"),
    BuildDependency("Xorg_xproto_jll"),
    Dependency("Zlib_jll"),
]

# Build the tarballs, and possibly a `build.jl` as well.
# GCC version 7 because of ffmpeg, but building against Qt requires v8 on Windows.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               preferred_gcc_version = v"8")
