# SurvivalMakie.jl changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Changed

- The Kaplan-Meier estimate is now computed with
  [SurvivalModels.jl](https://github.com/JuliaSurv/SurvivalModels.jl) instead of
  Survival.jl. Curves and confidence bands are unchanged, but risk-table counts now
  include observations recorded at time zero (Survival.jl silently dropped these).
