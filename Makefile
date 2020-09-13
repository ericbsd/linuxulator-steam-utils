.if !defined(OSVERSION)
OSVERSION != awk '/^\#define[[:blank:]]__FreeBSD_version/ {print $$3}' < /usr/include/sys/param.h # from bsd.port.mk
.endif

PROJECT = steam-utils

BUILD_DIR ?= .
PREFIX    ?= /opt

CFLAGS = --sysroot=/compat/linux -std=c99 -Wall -Wextra -Wno-unused-parameter

# r353724, r353725
.if $(OSVERSION) >= 1300054
CFLAGS += -DSKIP_FUTEX_WORKAROUND
.endif

# r355065-r355068; r355372
.if $(OSVERSION) >= 1300062 # ($(OSVERSION) >= 1201504 && $(OSVERSION) < 1300000)
CFLAGS += -DSKIP_EPOLLONESHOT_WORKAROUND
.endif

# r362806
.if $(OSVERSION) > 1300100
CFLAGS += -DSKIP_PROC_SELF_TASK_WORKAROUND
.endif

# r357493, r363130
.if $(OSVERSION) > 1300101
CFLAGS += -DSKIP_CLOCK_GETTIME_WORKAROUND
.endif

LIBS  = lib32/steamfix/steamfix.so    \
        lib32/fakenm/libnm-glib.so.4  \
        lib32/fakepulse/libpulse.so.0 \
        lib64/fakepulse/libpulse.so.0 \
        lib32/fakeudev/libudev.so.0   \
        lib64/fakeudev/libudev.so.0   \
        lib32/pathfix/pathfix.so      \
        lib64/pathfix/pathfix.so      \
        lib32/protonfix/protonfix.so  \
        lib64/protonfix/protonfix.so  \
        lib64/webfix/webfix.so

# r358483
.if $(OSVERSION) < 1300082
LIBS += lib32/fmodfix/fmodfix.so lib64/fmodfix/fmodfix.so
.endif

BINS  = lxbin/fhelper32 lxbin/fhelper64

LIBS := ${LIBS:C|(.*)|$(BUILD_DIR)/\1|}
BINS := ${BINS:C|(.*)|$(BUILD_DIR)/\1|}

build: $(LIBS) $(BINS)

.for b in 32 64

$(BUILD_DIR)/lib$(b)/steamfix/steamfix.so: src/steamfix.c src/epoll.c src/futexes.c src/pathfix.c
	mkdir -p $(BUILD_DIR)/lib$(b)/steamfix
	/compat/linux/bin/cc -m$(b) $(CFLAGS) -fPIC -shared -o $(.TARGET) src/steamfix.c src/epoll.c src/futexes.c src/pathfix.c -pthread -ldl -lm

$(BUILD_DIR)/lib$(b)/fakenm/libnm-glib.so.4: src/fakenm.c
	mkdir -p $(BUILD_DIR)/lib$(b)/fakenm
	/compat/linux/bin/cc -m$(b) $(CFLAGS) -fPIC -shared -o $(.TARGET) src/fakenm.c

$(BUILD_DIR)/lib$(b)/fakepulse/libpulse.so.0: src/fakepulse.c
	mkdir -p $(BUILD_DIR)/lib$(b)/fakepulse
	/compat/linux/bin/cc -m$(b) $(CFLAGS) -fPIC -shared -o $(.TARGET) src/fakepulse.c

$(BUILD_DIR)/lib$(b)/fakeudev/libudev.so.0: src/fakeudev.c
	mkdir -p $(BUILD_DIR)/lib$(b)/fakeudev
	/compat/linux/bin/cc -m$(b) $(CFLAGS) -fPIC -shared -o $(.TARGET) src/fakeudev.c

$(BUILD_DIR)/lib$(b)/fmodfix/fmodfix.so: src/fmodfix.c
	mkdir -p $(BUILD_DIR)/lib$(b)/fmodfix
	/compat/linux/bin/cc -m$(b) $(CFLAGS) -fPIC -shared -o $(.TARGET) src/fmodfix.c

$(BUILD_DIR)/lib$(b)/pathfix/pathfix.so: src/pathfix.c
	mkdir -p $(BUILD_DIR)/lib$(b)/pathfix
	/compat/linux/bin/cc -m$(b) $(CFLAGS) -fPIC -shared -o $(.TARGET) src/pathfix.c -ldl

$(BUILD_DIR)/lib$(b)/protonfix/protonfix.so: src/protonfix.c src/epoll.c
	mkdir -p $(BUILD_DIR)/lib$(b)/protonfix
	/compat/linux/bin/cc -m$(b) $(CFLAGS) -fPIC -shared -o $(.TARGET) src/protonfix.c src/epoll.c -pthread -ldl

$(BUILD_DIR)/lib$(b)/webfix/webfix.so: src/webfix.c src/futexes.c
	mkdir -p $(BUILD_DIR)/lib$(b)/webfix
	/compat/linux/bin/cc -m$(b) $(CFLAGS) -fPIC -shared -o $(.TARGET) src/webfix.c src/futexes.c -pthread -ldl -lm

$(BUILD_DIR)/lxbin/fhelper$(b): src/futex_helper.c
	mkdir -p $(BUILD_DIR)/lxbin
	/compat/linux/bin/cc -m$(b) $(CFLAGS) -o $(.TARGET) src/futex_helper.c

.endfor

clean:
.for f in $(LIBS) $(BINS)
.  if exists($f)
	rm $f
.  endif
.endfor

install:
	install -d $(PREFIX)/$(PROJECT)
	install -d $(PREFIX)/$(PROJECT)/bin
	install -d $(PREFIX)/$(PROJECT)/lib32
	install -d $(PREFIX)/$(PROJECT)/lib64
	install -d $(PREFIX)/$(PROJECT)/lxbin
.for f in $(LIBS) $(BINS)
	install -d `dirname $(PREFIX)/$(PROJECT)/${f:C|$(BUILD_DIR)/(.*)|\1|}`
	install $(f) $(PREFIX)/$(PROJECT)/${f:C|$(BUILD_DIR)/(.*)|\1|}
.endfor
	install bin/steam bin/steam-install $(PREFIX)/$(PROJECT)/bin
	install lxbin/dbus-launch lxbin/file* lxbin/patch-steam* lxbin/python3 lxbin/upgrade-steam-runtime* $(PREFIX)/$(PROJECT)/lxbin

deinstall:
.if exists($(PREFIX)/$(PROJECT))
	rm -r -I $(PREFIX)/$(PROJECT)
.endif

NVIDIA_DEPS != \
	case `sysctl -q hw.nvidia.version | sed -n "s/hw.nvidia.version: NVIDIA UNIX x86_64 Kernel Module  \([0-9]*\).*/\1/p"` in \
	  '')  echo '' ;;                   \
	  340) echo linux-nvidia-libs-340;; \
	  390) echo linux-nvidia-libs-390;; \
	  *)   echo linux-nvidia-libs;;     \
	esac

DEPS = ruby ca_root_nss liberation-fonts-ttf linux-c7-alsa-plugins-oss linux-c7-dbus-libs linux-c7-devtools linux-c7-dri linux-c7-gtk2 linux-c7-nss

dependencies:
	pkg install -r FreeBSD ${DEPS} ${NVIDIA_DEPS}
