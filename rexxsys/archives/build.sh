dd if=/dev/zero of=rexx.img bs=512 count=$[9 * 2 * 40]
MYPWD="$(pwd)"
cat >~/.mtoolsrc << EOD
drive q:
   file="$MYPWD/rexx.img"
EOD
mformat -f 360 q:
for file in rexxibm.exe rexxibmr.exe rexxsys.sys ttgocga.bat
do
mcopy $file q:
done
