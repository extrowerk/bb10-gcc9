BlackBerry 10 Toolchain builder

--------------------------------------------------------------------------------
CONTENTS

 * Introduction
 * Requirements
 * Contents
 * Configuration
 * Building
 * Bugs
 * Story
 * Diary
 
--------------------------------------------------------------------------------
 Introduction
 
 The BlackBerry 10 Toolchain builder compiles the GNU gcc-9.3.0 compiler,
 enabling developers to use more current tools than those included with the
 official Momentics SDK.
 
 Home: https://didacticode.ca/blog/development-tools-for-blackberry-10
 
--------------------------------------------------------------------------------
 Requirements
 
 * Internet connection and 5GB disk space (official SDK + these tools)
 
 * POSIX-compatible Operating System with an installed gcc C++ compiler, basic
 development tools (text editor, bzip2-aware tar, make...), wget, Java 1.8+ 
 
 * BlackBerry's official Native SDK, installed and working:
 http://developer.blackberry.com/native/downloads/
 - Some prerequisites might need to be manually installed
 http://developer.blackberry.com/native/downloads/requirements/
  
--------------------------------------------------------------------------------
Contents

BB10-Tools/
* build.sh: main build script
* env.sh: script containing environment definitions. Sourced by build.sh.
* {binutils, gcc, qnx-include}-*.patch.tar.gz: compressed patch files
* src: build directory created by script
--------------------------------------------------------------------------------
 Configuration
 
* Extract the archive into a location to which you have write access

* Edit env.sh:
	- define the locations of your BlackBerry sdk [default: ${HOME}/Apps/bbndk]
	- define the target installation directory [default: ${HOME}/Apps/qnx800]
	- define source download directory [default: ${HOME}/Downloads/src]
	
--------------------------------------------------------------------------------
Building

* Extensive testing has not been performed, but things should work reliably

* build everything
./build.sh all build
./build.sh all install

* build separately
./build.sh binutils build
./build.sh binutils install
./build.sh libgcc build
./build.sh libgcc install
./build.sh libstdc++ build
./build.sh libstdc++ install

* The directory structure is different from the official one to reduce nesting
{APP_ROOT}/qnx800/
/bin: executables
/include: headers
	/libstdc++: c++ includes (not the default c++, to allow for future multilib)
		/9.3.0: the new headers
		/4.*: old headers (unused. Use official tools for backwards compatibility)
	/libcpp: BlackBerry's Dinkum headers (not tested)
	/libc++: Future clang...?
/arm-blackberry-qnx8eabi: arm binaries
	/lib: BlackBerry core libs (libc, crt*...)
	/usr/lib: BlackBerry system libs
	/bin: internal (untagged) binutils and gcc executables
/x86_64-linux/arm-blackberry-qnx8eabi/lib64: binutils libraries
/x86_64-linux/arm-blackberry-qnx8eabi/lib64/gcc: gcc internals

--------------------------------------------------------------------------------
Bugs

* <cmath> still needs some configuration to work with libc's <math.h>
	- Workaround: use math.h

* <execution> not available
	- Workaround: None. This requires a custom implementation. TODO

--------------------------------------------------------------------------------
Story

The build script will copy the official QNX headers and libraries into the 
install directory, creating a toolchain that works independently of Momentics.

BlackBerry's deployment tools are still required to upload software onto devices
so you will need to use Momentics, or manually do so from the command line.
Scripts that ease launching software independently of Momentics are coming soon.

When completed, you will have an (almost) fully-functional gcc-9.3.0 C/C++ 
compiler capable of building POSIX-compatible software with minimal changes. QNX
has proven itself outstanding in this respect. While challenging, it always 
feels like working with a full-featured OS. One could simply look at the way the
other systems work and find the equivalent, even identical, QNX parts to use.

Unfortunately, C++17's std::execution library does not work. This is not a fault
with QNX. Gcc uses Intel's Thread Building Blocks to provide the parallelism
functionality, and Intel has opted to use the deprecated POSIX function:
getcontext(). This function was deprecated before POSIX 2008, but it seems most 
other OS's have retained it. I have read that there is a working implementation
of TBB for QNX somewhere, and my (naive and inexperienced) intuition tells me 
it's possible to adapt QNX's /proc filesystem to provide the register load/store
that getcontext() provides... or perhaps another way.  

I can't blame QNX for this. (It feels nice having fair cause to question the
desktop/server OS's design decisions, because QNX can do everything they can, 
from what I have seen so far). BlackBerry 10 was released "whole."
BlackBerry did not trim QNX down or hide features that "are not needed on 
mobile/embedded devices." Its All there!!

The built compiler will provide both static and shared gcc libraries. You can 
link with both static and shared libraries provided by the BlackBerry 10
SDK, but it seems, for the moment, that the Cascades UI libraries cannot be
linked with libstdc++. Cascades was compiled against BlackBerry's licensed 
Dinkum C++ library, which uses different internal names from gcc.

With some care, however I have been able to compile and link Cascades code with
C++17 code that is header-only, i.e. does not require linking with libstdc++,
(e.g. <algorithm>). I do so by first compiling the C++ code to assembly and then 
building those files with the bbndk compiler.

Shared libraries are the preferred modules on BB10, and there are even some 
BlackBerry libraries that do not provide static versions. For most, QNX provides
a static 'libary.a', a Position-Independent-Code (PIC) 'libraryS.a' (note 'S')
and a dynamic PIC shared 'library.so'. I still haven't quite mastered linking 
with static libraries, but the shared libraries work perfectly... PERFECTLTY! 

A lot of credit and gratitude has to go to the developers at BlackBerry, GNU and
anyone who contributed to making GCC and QNX the excellent works that they are.
Certain core elements would not have been possible without contributions/input 
from these incredible people.

Spending four hours staring at twenty lines of assembly code, that does nothing 
but list a set of modules to compiile, is all one needs to gain a better 
appreciation for what goes into building a compiler, let alone an operating 
system. I often lament that modern software standards are lax, but I pray that 
I never grow so self-righteous, desperate or mindless that I would see the 
faults in another person's work and fail to recognize the effort they put into 
it. There is systemic good in the world and it goes unnoticed when people draw 
turn to the bold, brash, rapid, imposing, disruptive realizations of the present, 
instead of building upon the slow, small, painstaking, compromise-laden efforts 
of our shared history. 

Good begets good, and I can only hope that this work is useful, does some good, 
or is appropriated to some other good purpose.

I love that BlackBerry 10 is able to embody this sense of historical connection
and relevance. There is a lot to learn about software efficiency, compatibility 
and industrial design that I feel is not fostered by the way other mobile 
Operating Systems treat software as disposable.

This is why I've decided to put my efforts towards a BlackBerry 10 development 
environment. QNX's POSIX compatibility assures that whatever I build for BB10 
will be easy to port to other platforms, but will have a better sense for 
structure and efficiency. This is going to be critical as computer devices get 
smaller and the negative effects of current software practices become 
impossible to ignore.

I hope I will one day be able to say that "This software comes with a guarantee 
and is fit and certified for the aforementioned use..." (in all caps). For now, 
this software is presented as is, and is probably covered by the LGPL because it 
relies on modifications to GCC itself. The QNX patches are provided with 
caution, because the QNX headers they modify are BlackBerry's property.

Program your World and enjoy it. Get to Work!

--------------------------------------------------------------------------------
 Diary
 
 08Mar2021:
  - Corrected/improved crossconfig.m4 by forcing newlib in configure.ac
  to read it. Our header defines are now being fully added to libstdc++
  - libstdc++ depends on libsocket for sysctl(), but it's not linking easily.
 