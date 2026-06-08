# lex-risk — Black-Scholes European options pricing
#
# Prices European call and put options and computes the standard Greeks.
# All computation is in Float (std.math operates on Float). Decimal
# inputs can be converted with option_inputs / from_decimal.
#
# N(x) — standard normal CDF — is approximated via Abramowitz & Stegun
# formula 26.2.17 (max absolute error < 7.5e-8). std.math has no erf.
#
# Pure: no effects.

import "std.math" as math
import "std.float" as float
import "std.int" as int
import "lex-money/src/decimal" as d

type OptionInputs = {
  spot   :: Float,   # S
  strike :: Float,   # K
  rate   :: Float,   # r (annual continuous)
  vol    :: Float,   # σ (annual)
  expiry :: Float,   # T (years)
}

# Standard normal probability density function
fn normal_pdf(x :: Float) -> Float {
  let two_pi := 6.283185307179586
  math.exp(0.0 - (x * x / 2.0)) / math.sqrt(two_pi)
}

# Standard normal CDF via Abramowitz & Stegun 26.2.17 (max error < 7.5e-8)
fn norm_cdf(x :: Float) -> Float {
  let ax := math.abs(x)
  let t := 1.0 / (1.0 + 0.2316419 * ax)
  let poly := t * (0.319381530 + t * (0.0 - 0.356563782 + t * (1.781477937 + t * (0.0 - 1.821255978 + t * 1.330274429))))
  let upper := 1.0 - normal_pdf(ax) * poly
  if x >= 0.0 {
    upper
  } else {
    1.0 - upper
  }
}

# d1 component of Black-Scholes formula
fn d1(inputs :: OptionInputs) -> Float {
  let s := inputs.spot
  let k := inputs.strike
  let r := inputs.rate
  let v := inputs.vol
  let t := inputs.expiry
  (math.log(s / k) + (r + v * v / 2.0) * t) / (v * math.sqrt(t))
}

# d2 component of Black-Scholes formula
fn d2(inputs :: OptionInputs) -> Float {
  let v := inputs.vol
  let t := inputs.expiry
  d1(inputs) - v * math.sqrt(t)
}

# European call price: S*N(d1) - K*e^(-rT)*N(d2)
fn call_price(inputs :: OptionInputs) -> Float {
  let s := inputs.spot
  let k := inputs.strike
  let r := inputs.rate
  let t := inputs.expiry
  let d1v := d1(inputs)
  let d2v := d2(inputs)
  let discount := k * math.exp(0.0 - r * t)
  s * norm_cdf(d1v) - discount * norm_cdf(d2v)
}

# European put price: K*e^(-rT)*N(-d2) - S*N(-d1)
fn put_price(inputs :: OptionInputs) -> Float {
  let s := inputs.spot
  let k := inputs.strike
  let r := inputs.rate
  let t := inputs.expiry
  let d1v := d1(inputs)
  let d2v := d2(inputs)
  let discount := k * math.exp(0.0 - r * t)
  discount * norm_cdf(0.0 - d2v) - s * norm_cdf(0.0 - d1v)
}

# Call delta: N(d1)
fn call_delta(inputs :: OptionInputs) -> Float {
  norm_cdf(d1(inputs))
}

# Put delta: N(d1) - 1
fn put_delta(inputs :: OptionInputs) -> Float {
  norm_cdf(d1(inputs)) - 1.0
}

# Gamma (same for call and put): N'(d1) / (S * σ * sqrt(T))
fn gamma(inputs :: OptionInputs) -> Float {
  let s := inputs.spot
  let v := inputs.vol
  let t := inputs.expiry
  normal_pdf(d1(inputs)) / (s * v * math.sqrt(t))
}

# Vega: S * N'(d1) * sqrt(T) * 0.01  (per 1% vol move)
fn vega(inputs :: OptionInputs) -> Float {
  let s := inputs.spot
  let t := inputs.expiry
  s * normal_pdf(d1(inputs)) * math.sqrt(t) * 0.01
}

# Call theta: (-S*N'(d1)*σ/(2*sqrt(T)) - r*K*e^(-rT)*N(d2)) / 365
fn call_theta(inputs :: OptionInputs) -> Float {
  let s := inputs.spot
  let k := inputs.strike
  let r := inputs.rate
  let v := inputs.vol
  let t := inputs.expiry
  let d1v := d1(inputs)
  let d2v := d2(inputs)
  let discount := k * math.exp(0.0 - r * t)
  (0.0 - s * normal_pdf(d1v) * v / (2.0 * math.sqrt(t)) - r * discount * norm_cdf(d2v)) / 365.0
}

# Put theta: (-S*N'(d1)*σ/(2*sqrt(T)) + r*K*e^(-rT)*N(-d2)) / 365
fn put_theta(inputs :: OptionInputs) -> Float {
  let s := inputs.spot
  let k := inputs.strike
  let r := inputs.rate
  let v := inputs.vol
  let t := inputs.expiry
  let d1v := d1(inputs)
  let d2v := d2(inputs)
  let discount := k * math.exp(0.0 - r * t)
  (0.0 - s * normal_pdf(d1v) * v / (2.0 * math.sqrt(t)) + r * discount * norm_cdf(0.0 - d2v)) / 365.0
}

# Call rho: K*T*e^(-rT)*N(d2) * 0.01  (per 1bp rate move)
fn call_rho(inputs :: OptionInputs) -> Float {
  let k := inputs.strike
  let r := inputs.rate
  let t := inputs.expiry
  let d2v := d2(inputs)
  k * t * math.exp(0.0 - r * t) * norm_cdf(d2v) * 0.01
}

# Put rho: -K*T*e^(-rT)*N(-d2) * 0.01
fn put_rho(inputs :: OptionInputs) -> Float {
  let k := inputs.strike
  let r := inputs.rate
  let t := inputs.expiry
  let d2v := d2(inputs)
  0.0 - k * t * math.exp(0.0 - r * t) * norm_cdf(0.0 - d2v) * 0.01
}

# Convert a Decimal to Float
fn from_decimal(dec :: d.Decimal) -> Float {
  let coeff := int.to_float(dec.coefficient)
  let scale := math.pow(10.0, int.to_float(dec.exponent))
  coeff * scale
}

# Construct OptionInputs from Decimal values and integer expiry in days
fn option_inputs(spot :: d.Decimal, strike :: d.Decimal, rate :: d.Decimal, vol :: d.Decimal, expiry_days :: Int) -> OptionInputs {
  { spot: from_decimal(spot), strike: from_decimal(strike), rate: from_decimal(rate), vol: from_decimal(vol), expiry: int.to_float(expiry_days) / 365.0 }
}
