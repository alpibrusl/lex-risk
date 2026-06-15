# Tests for greeks — equity delta and dollar-delta arithmetic.
#
# All tests are pure (no effects). Decimal notation:
# { coefficient: c, exponent: e } represents c × 10^e.

import "std.list" as list

import "lex-money/src/decimal" as d

import "lex-positions/src/position" as pos

import "../src/greeks" as greeks

fn pass() -> Result[Unit, Str] {
  Ok(())
}

fn fail(why :: Str) -> Result[Unit, Str] {
  Err(why)
}

fn assert_true(cond :: Bool, label :: Str) -> Result[Unit, Str] {
  if cond {
    pass()
  } else {
    fail(label)
  }
}

fn assert_eq_int(a :: Int, b :: Int, label :: Str) -> Result[Unit, Str] {
  assert_true(a == b, label)
}

fn assert_eq_dec(a :: d.Decimal, b :: d.Decimal, label :: Str) -> Result[Unit, Str] {
  assert_true(d.eq(a, b), label)
}

fn price(c :: Int, e :: Int) -> d.Decimal {
  { coefficient: c, exponent: e }
}

fn long_aapl() -> pos.Position {
  { key: { account: "ACC1", symbol: "AAPL" }, qty: 100, avg_cost: price(17500, -2), realized_pnl: d.zero() }
}

fn short_msft() -> pos.Position {
  { key: { account: "ACC1", symbol: "MSFT" }, qty: 0 - 50, avg_cost: price(42000, -2), realized_pnl: d.zero() }
}

fn flat_tsla() -> pos.Position {
  { key: { account: "ACC1", symbol: "TSLA" }, qty: 0, avg_cost: d.zero(), realized_pnl: d.zero() }
}

# ---- Long position --------------------------------------------------
fn test_long_delta_equals_qty() -> Result[Unit, Str] {
  let g := greeks.equity_greeks(long_aapl(), price(17500, -2))
  assert_eq_int(g.delta, 100, "long delta = qty")
}

fn test_long_dollar_delta() -> Result[Unit, Str] {
  let g := greeks.equity_greeks(long_aapl(), price(17500, -2))
  assert_eq_dec(g.dollar_delta, price(1750000, -2), "long dollar delta = 17500.00")
}

# ---- Short position -------------------------------------------------
fn test_short_delta_is_negative() -> Result[Unit, Str] {
  let g := greeks.equity_greeks(short_msft(), price(42000, -2))
  assert_eq_int(g.delta, 0 - 50, "short delta = -qty")
}

fn test_short_dollar_delta_is_negative() -> Result[Unit, Str] {
  let g := greeks.equity_greeks(short_msft(), price(42000, -2))
  assert_eq_dec(g.dollar_delta, price(0 - 2100000, -2), "short dollar delta = -21000.00")
}

# ---- Flat position --------------------------------------------------
fn test_flat_delta_is_zero() -> Result[Unit, Str] {
  let g := greeks.equity_greeks(flat_tsla(), price(25000, -2))
  assert_eq_int(g.delta, 0, "flat delta = 0")
}

fn test_flat_dollar_delta_is_zero() -> Result[Unit, Str] {
  let g := greeks.equity_greeks(flat_tsla(), price(25000, -2))
  assert_true(d.is_zero(g.dollar_delta), "flat dollar delta = 0")
}

# ---- abs_delta ------------------------------------------------------
fn test_abs_delta_long() -> Result[Unit, Str] {
  let g := greeks.equity_greeks(long_aapl(), price(17500, -2))
  assert_eq_int(greeks.abs_delta(g), 100, "abs delta long = 100")
}

fn test_abs_delta_short() -> Result[Unit, Str] {
  let g := greeks.equity_greeks(short_msft(), price(42000, -2))
  assert_eq_int(greeks.abs_delta(g), 50, "abs delta short = 50")
}

fn test_abs_delta_flat() -> Result[Unit, Str] {
  let g := greeks.equity_greeks(flat_tsla(), price(25000, -2))
  assert_eq_int(greeks.abs_delta(g), 0, "abs delta flat = 0")
}

# ---- Suite ----------------------------------------------------------
fn suite() -> List[Result[Unit, Str]] {
  [test_long_delta_equals_qty(), test_long_dollar_delta(), test_short_delta_is_negative(), test_short_dollar_delta_is_negative(), test_flat_delta_is_zero(), test_flat_dollar_delta_is_zero(), test_abs_delta_long(), test_abs_delta_short(), test_abs_delta_flat()]
}

fn run_all() -> Int {
  list.fold(suite(), 0, fn (acc :: Int, r :: Result[Unit, Str]) -> Int {
    match r {
      Ok(_) => acc,
      Err(_) => acc + 1,
    }
  })
}

