#!/bin/bash

ln_crawler(){
	for path in $TARG_DIR ; do
		if [ -L $path$1 ] ; then
			[ -L $DEST_DIR$1 ] && break
			ln -sf $( basename $( readlink $path$1 ) ) $DEST_DIR$1
			ln_crawler $( basename $( readlink $path$1 ) )
			break
		elif [ -f $path$1 ] ; then
			[ -f $DEST_DIR$1 ] && break
			cp $path$1 $DEST_DIR
			#chmod +x $DEST_DIR$1
			ld_crawler $1
			break
		fi
	done
}

ld_crawler(){
	for path in $TARG_DIR ; do
		if [ -f $path$1 ] ; then
			local LD_LIST
			LD_LIST=`readelf -d $path$1 |grep NEEDED`
			LD_LIST=${LD_LIST//"0x0000000000000001 (NEEDED)             Shared library: ["}
			LD_LIST=${LD_LIST//"]"}
			for ld_file in $LD_LIST ; do
				ln_crawler $ld_file
			done
		fi
	done
}

add_extra_pkg_src(){
	local suffix_found
	local src_pkg

	for suffix in $PKG_TYPES ; do
		for package in ${PACKAGES_$suffix} ; do

			if [ package == $1 ] ; then
				suffix_found=${suffix}
				break
			fi

		done

		src_pkg="${LAKKA_DIR}/${DISTRO_PACKAGES_SUBDIR}/${PKG_SUBDIR_$suffix_found}/$1/package.mk"


		if [ -f "$src_pkg" ] ; then
			pkg_ver=`cat $src_pkg | sed -En "s/PKG_VERSION=\"(.*)\"/\1/p"`
			SRC_EXTRA="$SRC_EXTRA ${LAKKA_DIR}/${LAKKA_BUILD_SUBDIR}/$1-${pkg_ver}/.install_pkg/usr/lib/"
			return 0
		fi
	done
	echo "Failed - no $1 package.mk"
	exit_script 1
}

hook_function(){
if [[ "$PROJECT" == "Amlogic-ng" && "$ARCH" == aarch64 ]] ; then
	#Patching ELF to set aarch64 local interpreter
	echo "Applying arm64_to_arm32_userspace hack"

	echo -e "\tPatching bin ELF "
	for bin_file in "${ADDON_DIR}"/bin/* ; do
		[[ "$bin_file" == *".sh" || "$bin_file" == *".start" ]] && continue
		echo -ne "\t\t$( basename $bin_file )"
		patchelf --set-interpreter ../lib/lib64/ld-linux-aarch64.so.1 "$bin_file" &>>"$LOG"
		[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit_script 1 ; }
	done

	#Creating lib64 directory
#	add_extra_pkg_src opengl-meson-coreelec
#	add_extra_pkg_src libcec

	LD64_SRC1="${LAKKA_DIR}/${LAKKA_BUILD_SUBDIR}/toolchain/aarch64-libreelec-linux-gnueabi/sysroot/usr/lib/"
	LD64_SRC2="${LAKKA_DIR}/${LAKKA_BUILD_SUBDIR}/toolchain/aarch64-libreelec-linux-gnueabi/lib64/"
	TARG_DIR="${ADDON_DIR}/lib/ ${ADDON_DIR}/bin/ ${SRC_EXTRA} ${LD64_SRC1} ${LD64_SRC2} ${ADDON_DIR}/usr/lib/libretro/"
	echo -e "\tCreating lib64 directory"
	DEST_DIR="${ADDON_DIR}/lib/lib64/"
	mkdir -p "$DEST_DIR"
	for bin_file in "${ADDON_DIR}"/bin/* ; do
		[[ "$bin_file" == *".sh" || "$bin_file" == *".start" ]] && continue
		echo -ne "\t\tCrawling $( basename $bin_file )"
		ld_crawler "$( basename $bin_file )"
		[ $? -eq 0 ] && echo "(ok)" || { echo "(failed - can't patchelf)" ; exit_script 1 ; }
	done
	echo

	#Workaround: overwrite cec-mini-kb aarch64 with arm version as parallel libcec aarch64 gives bus error and cannot find CEC device. TODO FIXME
	echo "$CEC_ARM_BIN" | base64 --decode > bin/cec-mini-kb
	chmod +x bin/cec-mini-kb
fi
}

PKG_TYPES="$PKG_TYPES DEVEL"
PKG_SUBDIR_DEVEL="devel"
PACKAGES_DEVEL="libcec"

PACKAGES_SYSUTILS="$PACKAGES_SYSUTILS opengl-meson-coreelec"

HOOK_RETROARCH_START_0="LD_LIBRARY_PATH=\"\$LD_LIBRARY_PATH:\$ADDON_DIR/lib/lib64\""
HOOK_RETROARCH_START_1="LD_LIBRARY_PATH=\"\${LD_LIBRARY_PATH//\\:\${ADDON_DIR//\\//\\\\\\/}\\/lib\\/lib64}\""

read -d '' HOOK_RETROARCH_START_2 <<EOF
cd \$ADDON_DIR/lib/lib64
for file_src in * ; do
	size_scr=\$(wc -c \$file_src)
	if [ \${size_scr//" \$file_src"} -lt 100 -a ! -L \$file_src ]; then
		[ -f \$(cat \$file_src) ] && ln -sf \$(cat \$file_src) \$file_src
	fi
	chmod +x \$file_src
done
cd - > /dev/null
EOF

read -d '' CEC_ARM_BIN <<EOF
f0VMRgEBAQAAAAAAAAAAAAIAKAABAAAA9IwAADQAAAAYIgAAAAQABTQAIAAKACgAHgAdAAYAAAA0
AAAANIAAADSAAABAAQAAQAEAAAQAAAAEAAAAAwAAAHQBAAB0gQAAdIEAABkAAAAZAAAABAAAAAEA
AAABAAAAAAAAAACAAAAAgAAAWBYAAFgWAAAFAAAAABAAAAEAAAD0HgAA9K4AAPSuAACYAQAA2AIA
AAYAAAAAEAAAAgAAAAAfAAAArwAAAK8AAAABAAAAAQAABgAAAAQAAAAEAAAAkAEAAJCBAACQgQAA
IAAAACAAAAAEAAAABAAAAFDldGRQFgAAUJYAAFCWAAAIAAAACAAAAAQAAAAEAAAAUeV0ZAAAAAAA
AAAAAAAAAAAAAAAAAAAABgAAABAAAAABAABwDBYAAAyWAAAMlgAAQAAAAEAAAAAEAAAABAAAAFLl
dGT0HgAA9K4AAPSuAAAMAQAADAEAAAYAAAAEAAAAL2xpYi9sZC1saW51eC1hcm1oZi5zby4zAAAA
AAQAAAAQAAAAAQAAAEdOVQAAAAAAAwAAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAA
AAAAABIAAAAbAAAAAAAAAAAAAAASAAAALQAAAAAAAAAAAAAAEgAAAD4AAAAAAAAAAAAAACAAAABN
AAAAAAAAAAAAAAASAAAAVAAAAAAAAAAAAAAAEgAAAF4AAAAAAAAAAAAAACAAAAB6AAAAAAAAAAAA
AAAgAAAAlAAAAAAAAAAAAAAAEgAAAJsAAAAAAAAAAAAAABIAAACiAAAAAAAAAAAAAAASAAAAqAAA
AAAAAAAAAAAAEgAAALoAAAAAAAAAAAAAABIAAADCAAAAAAAAAAAAAAASAAAAyAAAAAAAAAAAAAAA
EgAAAM0AAAAAAAAAAAAAABIAAAAgAQAAAAAAAAAAAAASAAAAWwEAAAAAAAAAAAAAEgAAAGsBAAAA
AAAAAAAAABIAAACYAQAAAAAAAAAAAAASAAAAoAEAAAAAAAAAAAAAEgAAAKYBAAAAAAAAAAAAABIA
AACtAQAAAAAAAAAAAAASAAAAtwEAAAAAAAAAAAAAEgAAAMEBAAAAAAAAAAAAABIAAAAAAgAAAAAA
AAAAAAASAAAAFQIAAAAAAAAAAAAAEgAAACgCAAAAAAAAAAAAABIAAABDAgAAAAAAAAAAAAASAAAA
WwIAAAAAAAAAAAAAEgAAADkCAABAsQAAjAAAABEAGQDeAQAALLEAABAAAAChABkAYQEAAKCwAACM
AAAAEQAZAHsCAADwiQAAAAAAABIAAAAAYWJvcnQAR0xJQkNfMi40AGxpYmMuc28uNgBfX2xpYmNf
c3RhcnRfbWFpbgBfX2Vycm5vX2xvY2F0aW9uAF9fZ21vbl9zdGFydF9fAHNpZ25hbABuYW5vc2xl
ZXAAX0lUTV9kZXJlZ2lzdGVyVE1DbG9uZVRhYmxlAF9JVE1fcmVnaXN0ZXJUTUNsb25lVGFibGUA
c3RyY3B5AG1lbXNldABjbG9zZQBkbG9wZW4AbGliZGwuc28uMgBkbGVycm9yAGlvY3RsAG9wZW4A
X1pTdGxzSVN0MTFjaGFyX3RyYWl0c0ljRUVSU3QxM2Jhc2ljX29zdHJlYW1JY1RfRVM1X1BLYwBH
TElCQ1hYXzMuNABsaWJzdGRjKysuc28uNgBfWlN0NGVuZGxJY1N0MTFjaGFyX3RyYWl0c0ljRUVS
U3QxM2Jhc2ljX29zdHJlYW1JVF9UMF9FUzZfAGRsc3ltAF9aU3Q0Y291dABfX2FlYWJpX3Vud2lu
ZF9jcHBfcHIwAEdDQ18zLjUAbGliZ2NjX3Muc28uMQBkbGNsb3NlAHdyaXRlAHVzbGVlcABfWk5T
b2xzRWkAX1pOU3NEMUV2AF9fY3hhX2VuZF9jbGVhbnVwAENYWEFCSV8xLjMAX1pOU3M0X1JlcDIw
X1NfZW1wdHlfcmVwX3N0b3JhZ2VFAF9fZ3h4X3BlcnNvbmFsaXR5X3YwAF9aTlNzQzFFUEtjUktT
YUljRQBfWk5LU3M0Y29weUVQY2pqAF9aU3Q0Y2VycgBfWk5TdDhpb3NfYmFzZTRJbml0QzFFdgBf
X2FlYWJpX2F0ZXhpdABDWFhBQklfQVJNXzEuMy4zAF9aTlN0OGlvc19iYXNlNEluaXREMUV2AAAD
AAAAHwAAAAEAAAAFAAAAITMQAB8AAAAgAAAAIQAAACVtDEONWUDxFJgMQylF1UwAAAIAAgACAAAA
AgACAAAAAAACAAIAAgADAAMAAgACAAQABAADAAcAAwACAAIABAAEAAUABQAEAAQABAAGAAQABAAE
AAQAAAABAAEAEQAAABAAAAAgAAAAFGlpDQAAAgAHAAAAAAAAAAEAAQCvAAAAEAAAACAAAAAUaWkN
AAADAAcAAAAAAAAAAQADABEBAAAQAAAAQAAAAHQpkggAAAQABQEAABAAAADTr2sFAAAFANMBAAAQ
AAAAo69JCAAABgBqAgAAAAAAAAEAAQCKAQAAEAAAAAAAAABVJnkLAAAHAIIBAAAAAAAADLAAABUE
AABAsQAAFB8AACyxAAAUIAAAoLAAABQhAAAcsAAAFgIAACCwAAAWAQAAJLAAABYEAAAosAAAFgwA
ACywAAAWDQAAMLAAABYQAAA0sAAAFhEAADiwAAAWEgAAPLAAABYUAABAsAAAFhUAAESwAAAWFgAA
SLAAABYXAABMsAAAFhgAAFCwAAAWGQAAVLAAABYPAABYsAAAFg4AAFywAAAWCgAAYLAAABYJAABk
sAAAFgsAAGiwAAAWGgAAbLAAABYFAABwsAAAFhsAAHSwAAAWHAAAeLAAABYGAAB8sAAAFgMAAICw
AAAWHQAAhLAAABYeAACIsAAAFiIAAAhALekmAQDrCIC96ATgLeUE4J/lDuCP4AjwvuVoJwAAAMaP
4gLKjOJo97zlAMaP4gLKjOJg97zlAMaP4gLKjOJY97zlAMaP4gLKjOJQ97zlAMaP4gLKjOJI97zl
AMaP4gLKjOJA97zlAMaP4gLKjOI497zlAMaP4gLKjOIw97zlAMaP4gLKjOIo97zlAMaP4gLKjOIg
97zlAMaP4gLKjOIY97zlAMaP4gLKjOIQ97zlAMaP4gLKjOII97zlAMaP4gLKjOIA97zlAMaP4gLK
jOL49rzlAMaP4gLKjOLw9rzlAMaP4gLKjOLo9rzlAMaP4gLKjOLg9rzlAMaP4gLKjOLY9rzlAMaP
4gLKjOLQ9rzlAMaP4gLKjOLI9rzlAMaP4gLKjOLA9rzlAMaP4gLKjOK49rzlAMaP4gLKjOKw9rzl
AMaP4gLKjOKo9rzlAMaP4gLKjOKg9rzlAMaP4gLKjOKY9rzlAMaP4gLKjOKQ9rzl8EEt6QIAoOOM
Ep/lUtxN4hjQTeLh///rAQBw4wcAABoBQKDjdBKf5XQCn+Wu///rBACg4VLcjeIY0I3i8IG96FQS
n+UPAKDj1P//6wEAcOPy//8KsgEA6wBAUOIEAAAKQBKf5QJAoOM0Ap/lnv//6+7//+o0AI3iGECN
5RxAjeUYYI3iIECN5SRAjeUoQI3lLECN5TBAjeUDAgDrNACN4gECAOsAEp/lXi+N4gwAjeIYQI3l
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
4v3/65AQn+UqIKDjAACU5d79/+uAEJ/lOSCg4wAAlOXa/f/rcBCf5W8goOMAAJTl1v3/61ggoOMA
EKDjCACN4tX9/+tUMJ/lVBCf5QwAjeIEMI3leDYF47gwzeHR/f/rQBCf5QQgjeIAAJTlx/3/6wAA
lOUAIKDjARUF48P9/+vAP6DhAwCg4WDQjeIQgL3oCLAAANKUAABkVQRAZVUEQAMANBLelAAAA1Vc
QBBALekcQJ/lAACU5QAAUOMQgL0IAhUF47H9/+sAAJTlEEC96Lf9/+oIsAAAIBGf5QAwoOMAEIDl
ASCg48AQgOUBHKDjtBzA4UUfgOIwIMDlFsEA48YgwOUAIODjBOAt5boywOEsMIDlNDCA5SgwwOWw
IMHh3CCf5bDg0uECINLlvOCA4QLMoOMYIcDlBSCg4yQhgOVFIKDjLCGA5fovoOMwIYDlfS+g4zgh
gOXIIKDjPCGA5QUtgOIcMYDlIDHA5SgxgOU0MYDlsMDC4QIgoOMUIIDlGCCA5RwggOUgIIDlJCCA
5Q8goOPQIIDl1CCA4gQwwOUEMILkAgBR4fz//xo8MIDifCCA4gAQoOMEEIPkAgBT4fz//xoPMKDj
gCCA4nwwgOXAEIDiADCg4wQwguQBAFLh/P//GgEgoOM4MIDlvCCA5TwggOXIMIDlzDCA5QTwneQC
AAYATJQAAPBHLekAcKDhTGCf5UxQn+UBgKDhBmCP4AKQoOEFUI/gI/3/6wVgRuBGYbDh8Ie9CARQ
ReIAQKDjBDC15QFAhOIJIKDhCBCg4QcAoOEz/y/hBABW4ff//xrwh73oCBsAAPgaAAAe/y/hCEAt
6QiAvegBAAIAZW5nAGxpYmNlYy5zby42AENFQ0luaXRpYWxpc2UAY2Fubm90IGZpbmQgQ0VDSW5p
dGlhbGlzZQBDRUNEZXN0cm95AENFQ1N0YXJ0Qm9vdGxvYWRlcgBjYW5ub3QgZmluZCBDRUNTdGFy
dEJvb3Rsb2FkZXIAVW5tYXBwZWQgaW5wdXQ6IAAvZGV2L3VpbnB1dABjZWMtbWluaS1rYgBGYWls
ZWQgdG8gaW5zdGFsbCB0aGUgU0lHSU5UL1NJR1RFUk0gc2lnbmFsIGhhbmRsZXIKAFVuYWJsZSB0
byBpbml0aWFsaXplIHVpbnB1dCBkZXZpY2UhCgBDRUNfZGV2aWNlAEZhaWxlZCBsb2FkaW5nIGxp
YmNlYy5zbwoAQ291bGQgbm90IGF1dG9tYXRpY2FsbHkgZGV0ZXJtaW5lIHRoZSBjZWMgYWRhcHRl
ciBkZXZpY2VzCgBGYWlsZWQgdG8gb3BlbiB0aGUgQ0VDIGRldmljZSBvbiBwb3J0IAAAxPP/f7Co
AQD//wELPLABmAIAoAIEAAAArPP/fyiFsgGwsLCs//8BFixEAADMAQSYBQDsAYQDhAUAlAUEAAAA
APDz/3/U//9/sPb/fwEAAADc9/9/sLCqgDz5/38AhASAcPn/f7CwqIC8+f9/lP//f+T6/3+wqBeA
OPz/fwEAAAAAAAAAARv///j///8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AOCNAADEjAAAuI0AAAMAAAAQsAAAAgAAAOAAAAAXAAAArIcAABQAAAARAAAAEQAAAIyHAAASAAAA
IAAAABMAAAAIAAAAFQAAAAAAAAAGAAAAsIEAAAsAAAAQAAAABQAAAOCDAAAKAAAAkwIAAPX+/290
hgAAAQAAAK8AAAABAAAAEQEAAAEAAACKAQAAAQAAABEAAAAMAAAAjIgAAA0AAABAlAAAGQAAAPSu
AAAbAAAACAAAABoAAAD8rgAAHAAAAAQAAADw//9vpIYAAP7//2/shgAA////bwQAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP////8AAAAA
AAAAAAAAAAAAAAAAmIgAAJiIAACYiAAAmIgAAJiIAACYiAAAmIgAAJiIAACYiAAAmIgAAJiIAACY
iAAAmIgAAJiIAACYiAAAmIgAAJiIAACYiAAAmIgAAJiIAACYiAAAmIgAAJiIAACYiAAAmIgAAJiI
AACYiAAAmIgAAABHQ0M6IChHTlUpIDkuNC4wAAAABAAAAAkAAAAEAAAAR05VAGdvbGQgMS4xNgAA
AEE4AAAAYWVhYmkAAS4AAAAFOC1BAAYOB0EIAQkCDAMSBBMBFAEVARYBFwMYARkBGgIcASIBKgFE
AwAuc2hzdHJ0YWIALmludGVycAAubm90ZS5BQkktdGFnAC5keW5zeW0ALmR5bnN0cgAuZ251Lmhh
c2gALmdudS52ZXJzaW9uAC5nbnUudmVyc2lvbl9yAC5yZWwuZHluAC5yZWwucGx0AC5pbml0AC50
ZXh0AC5maW5pAC5yb2RhdGEALkFSTS5leHRhYgAuQVJNLmV4aWR4AC5laF9mcmFtZQAuZWhfZnJh
bWVfaGRyAC5pbml0X2FycmF5AC5maW5pX2FycmF5AC5keW5hbWljAC5kYXRhAC50bV9jbG9uZV90
YWJsZQAuZ290AC5ic3MALmNvbW1lbnQALm5vdGUuZ251LmdvbGQtdmVyc2lvbgAuQVJNLmF0dHJp
YnV0ZXMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALAAAAAQAAAAIA
AAB0gQAAdAEAABkAAAAAAAAAAAAAAAEAAAAAAAAAEwAAAAcAAAACAAAAkIEAAJABAAAgAAAAAAAA
AAAAAAAEAAAAAAAAACEAAAALAAAAAgAAALCBAACwAQAAMAIAAAQAAAABAAAABAAAABAAAAApAAAA
AwAAAAIAAADggwAA4AMAAJMCAAAAAAAAAAAAAAEAAAAAAAAAMQAAAPb//28CAAAAdIYAAHQGAAAw
AAAAAwAAAAAAAAAEAAAABAAAADsAAAD///9vAgAAAKSGAACkBgAARgAAAAMAAAAAAAAAAgAAAAIA
AABIAAAA/v//bwIAAADshgAA7AYAAKAAAAAEAAAABAAAAAQAAAAAAAAAVwAAAAkAAAACAAAAjIcA
AIwHAAAgAAAAAwAAAAAAAAAEAAAACAAAAGAAAAAJAAAAQgAAAKyHAACsBwAA4AAAAAMAAAAYAAAA
BAAAAAgAAABpAAAAAQAAAAYAAACMiAAAjAgAAAwAAAAAAAAAAAAAAAQAAAAAAAAAZAAAAAEAAAAG
AAAAmIgAAJgIAABkAQAAAAAAAAAAAAAEAAAAAAAAAG8AAAABAAAABgAAAPyJAAD8CQAARAoAAAAA
AAAAAAAABAAAAAAAAAB1AAAAAQAAAAYAAABAlAAAQBQAAAgAAAAAAAAAAAAAAAQAAAAAAAAAewAA
AAEAAAAyAAAASJQAAEgUAACDAQAAAAAAAAAAAAAEAAAAAAAAAIMAAAABAAAAAgAAAMyVAADMFQAA
PgAAAAAAAAAAAAAABAAAAAAAAACOAAAAAQAAcIIAAAAMlgAADBYAAEAAAAAMAAAAAAAAAAQAAAAI
AAAAmQAAAAEAAAACAAAATJYAAEwWAAAEAAAAAAAAAAAAAAAEAAAAAAAAAKMAAAABAAAAAgAAAFCW
AABQFgAACAAAAAAAAAAAAAAABAAAAAAAAACxAAAADgAAAAMAAAD0rgAA9B4AAAgAAAAAAAAAAAAA
AAQAAAAEAAAAvQAAAA8AAAADAAAA/K4AAPweAAAEAAAAAAAAAAAAAAAEAAAABAAAAMkAAAAGAAAA
AwAAAACvAAAAHwAAAAEAAAQAAAAAAAAABAAAAAgAAADSAAAAAQAAAAMAAAAAsAAAACAAAAwAAAAA
AAAAAAAAAAQAAAAAAAAA2AAAAAEAAAADAAAADLAAAAwgAAAAAAAAAAAAAAAAAAAEAAAAAAAAAOgA
AAABAAAAAwAAAAywAAAMIAAAgAAAAAAAAAAAAAAABAAAAAAAAADtAAAACAAAAAMAAACQsAAAjCAA
ADwBAAAAAAAAAAAAAAgAAAAAAAAA8gAAAAEAAAAwAAAAAAAAAIwgAAASAAAAAAAAAAAAAAABAAAA
AQAAAPsAAAAHAAAAAAAAAAAAAACgIAAAHAAAAAAAAAAAAAAABAAAAAAAAAASAQAAAwAAcAAAAAAA
AAAAvCAAADkAAAAAAAAAAAAAAAEAAAAAAAAAAQAAAAMAAAAAAAAAAAAAAPUgAAAiAQAAAAAAAAAA
AAABAAAAAAAAAA==
EOF