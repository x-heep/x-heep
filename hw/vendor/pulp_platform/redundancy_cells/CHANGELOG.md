# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased
### Added
- Add ECC correctors

### Changed
- Replace vendor.py script with bender vendor for ECC modules
- Update `ecc_manager` for configurability

## 0.5.1 - 2023-04-12
### Added
- Add CI flow for linting

### Fixed
- Fix ECC SRAM wrap

## 0.5.0 - 2022-12-21

### Added
- Add `pulpissimo_tcls` permanently voted TCLS configuration
- Add `ecc_manager` to log and errors
- Add resynchronization to ODRG and TCLS
- Expose additional error logging signals
- Add scrubber to ECC SRAM wrap
- Add testing signals for tapeout
- Add secded ECC corrector

### Changed
- Expose  `ecc_sram` ecc error signals
- Rename cTCLS to ODRG
- Hide bus ecc behind bender targets, remove related dependencies
- Update secded testbench to use correctors and fix error injection

## 0.4.0 - 2022-03-31

### Changed
- Clean up interface of `cTCLS_unit`

## 0.3.0 - 2022-01-04

### Added
- Add secded ECC for 64 bit datawidth
- Add ECC encoder for XBAR_DEMUX_BUS
- Add ECC encoder for AXI_BUS
- Add cTCLS unit
- Add initial ECC scrubber

### Changed
- Updated `axi` version
- Updated `hci` version
- Updatad `register_interface` version and aligned to new reggen_tool format

## 0.2.0 - 2021-01-12

### Added
- ECC encoder and decoder for XBAR_bus (PE, TCDM)
- Added TMR majority voters

## 0.1.0 - 2020-12-30

### Added
- lowrisc `secded_gen.py` script, along with generated modules for 8, 16, and 32 bit with minimum redundancy bits.
- initial wrapper for sram to include ecc
