# I2S DEMO application
The `example_i2s` application contains three selectable tests. Select them in
`test_i2s.h`:
- `TEST_ID_0`: RX-only DMA capture from the I2S microphone stream.
- `TEST_ID_1`: TX-only DMA transfer to the I2S serial output.
- `TEST_ID_2`: simultaneous TX and RX DMA transfers on different DMA channels.

The FPGA demo script is for the `TEST_ID_0` RX-only path. It reads from the
microphone and dumps the captured values.

This demo requires mcu_gen with `MEM_BANKS=16`
to record 2.52 seconds of audio.

## demo python script
First install
```
pip install pyserial matplotlib sounddevice  numpy
```

```
sudo apt-get install libasound-dev
```


Run 
```
python i2s_test.py /dev/ttyUSBx 1
```

The tranmisting of the data takes about 30sec so be patient...



## alternative - dump to file with minicom
```
sudo minicom --b 115200 -D /dev/ttyUSBx -C LOG_FILE
```
and anlyse wherever...
