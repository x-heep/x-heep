# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## 1.1.2 - 2024-08-30

- Removed ternary statement in `serial_link_physical` for better EDA tool compatibility.

## 1.1.1 - 2024-02-07

### Changed

- The DDR output data is now muxed by a normal signal instead of a clock signal. Some tools infer a clock gate when a clock signal is used as a mux select signal.

## 1.1.0 - 2023-07-03

### Changed
- Renamed clock division configuration registers to deliberately introduce breaking changes when using the old incorrect configuration registers.

### Fixed
- SW Clock division configuration

## 1.0.1 - 2023-03-13

### Changed
- Added `NoRegCdc` parameter to `serial_link` module to disable the CDC between the RegBus Clock and the System Clock

## 1.0.0 - 2023-01-26
- Initial release
