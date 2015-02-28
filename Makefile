LUVI_TAG=$(shell git describe)
LUVI_ARCH=$(shell uname -s)_$(shell uname -m)

NPROCS:=1
OS:=$(shell uname -s)

CMAKE_FLAGS+= -H. -Bbuild
ifdef GENERATOR
	CMAKE_FLAGS+= -G"${GENERATOR}"
endif

CPACK_FLAGS=-DWITH_PACKAGE_SH=ON -DWITH_PACKAGE_TGZ=ON -DWITH_PACKAGE_TBZ2=ON
ifdef CPACK_DEB
	CPACK_FLAGS=-DWITH_PACKAGE_DEB=ON
endif

ifdef CPACK_RPM
	CPACK_FLAGS=-DWITH_PACKAGE_RPM=ON
endif

ifdef CPACK_NSIS
	CPACK_FLAGS=-DWITH_PACKAGE_NSIS=ON
endif

ifdef CPACK_BUNDLE
	CPACK_FLAGS=-DWITH_PACKAGE_BUNDLE=ON
endif

ifeq ($(OS),Linux)
	NPROCS:=$(shell grep -c ^processor /proc/cpuinfo)
else ifeq ($(OS),Darwin)
	NPROCS:=$(shell sysctl hw.ncpu | awk '{print $$2}')
endif

ifndef GENERATOR
  EXTRA_OPTIONS:=-j${NPROCS}
endif

# This does the actual build and configures as default flavor is there is no build folder.
luvi: static

# Configure the build with minimal dependencies
tiny: deps/luv/CMakeLists.txt
	cmake $(CMAKE_FLAGS) $(CPACK_FLAGS)
	cmake --build build -- ${EXTRA_OPTIONS}

# Configure the build with everything, use shared libs when possible
large: deps/luv/CMakeLists.txt
	cmake $(CMAKE_FLAGS) $(CPACK_FLAGS) -DWithOpenSSL=ON -DWithZLIB=ON
	cmake --build build -- ${EXTRA_OPTIONS}

# Configure the build with everything, but statically link the deps
static: deps/luv/CMakeLists.txt
	cmake $(CMAKE_FLAGS) $(CPACK_FLAGS) -DWithOpenSSL=ON -DWithSharedOpenSSL=OFF -DWithZLIB=ON -DWithSharedZLIB=OFF
	cmake --build build -- ${EXTRA_OPTIONS}

package: deps/luv/CMakeLists.txt
	cmake --build build -- package

# In case the user forgot to pull in submodules, grab them.
deps/luv/CMakeLists.txt:
	git submodule update --init --recursive

clean:
	rm -rf build luvi.tar.gz

test: luvi
	rm -f test.bin
	LUVI_APP=samples/test.app build/luvi 1 2 3 4
	LUVI_APP=samples/test.app LUVI_TARGET=test.bin build/luvi
	LUVI_app= ./test.bin 1 2 3 4
	rm -f test.bin
install: luvi
	install -p build/luvi /usr/local/bin

uninstall:
	rm -f /usr/local/bin/luvi

reset:
	git submodule update --init --recursive && \
	git clean -f -d && \
	git checkout .

publish-src: reset
	tar -czvf luvi-src.tar.gz \
	  --exclude 'luvi-src.tar.gz' --exclude '.git*' --exclude build . && \
	github-release upload --user luvit --repo luvi --tag ${LUVI_TAG} \
	  --file luvi-src.tar.gz --name luvi-src.tar.gz

publish-tiny: reset
	$(MAKE) tiny test && \
	github-release upload --user luvit --repo luvi --tag ${LUVI_TAG} \
	  --file build/luvi --name luvi-tiny-${LUVI_ARCH}

publish-large: reset
	$(MAKE) large test && \
	github-release upload --user luvit --repo luvi --tag ${LUVI_TAG} \
	  --file build/luvi --name luvi-large-${LUVI_ARCH}

publish-static: reset
	$(MAKE) static test && \
	github-release upload --user luvit --repo luvi --tag ${LUVI_TAG} \
	  --file build/luvi --name luvi-static-${LUVI_ARCH}
