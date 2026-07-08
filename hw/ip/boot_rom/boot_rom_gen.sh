cd $(dirname "$0")
if [ -f .direct_rom ]; then
  echo "[boot_rom_gen] .direct_rom marker present — skipping stub regeneration, keeping app ROM"
  exit 0
fi
make clean && make all
