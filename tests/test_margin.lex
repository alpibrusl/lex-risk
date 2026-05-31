# Tests for margin — Reg-T initial/maintenance margin and pre-trade check.
#
# All tests are pure (no effects). Default config: 25% initial,
# 15% maintenance, $50,000 per-order cap.

import "std.list" as list

import "lex-money/src/decimal" as d

import "../src/margin" as margin

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

fn assert_eq_dec(a :: d.Decimal, b :: d.Decimal, label :: Str) -> Result[Unit, Str] {
  assert_true(d.eq(a, b), label)
}

fn price(c :: Int, e :: Int) -> d.Decimal {
  { coefficient: c, exponent: e }
}

fn cfg() -> margin.MarginConfig {
  margin.default_margin_config()
}

# ---- initial_margin -------------------------------------------------
# $100.00 × 25% = $25.00
# { coefficient: 10000, exponent: -2 } × { coefficient: 25, exponent: -2 }
# = { coefficient: 250000, exponent: -4 }

fn test_initial_margin_standard() -> Result[Unit, Str] {
  let notional := price(10000, -2)
  let im := margin.initial_margin(notional, cfg())
  assert_eq_dec(im, price(250000, -4), "initial margin $100 @ 25% = $25.00")
}

# $200,000.00 × 25% = $50,000.00
# notional = { coefficient: 20000000, exponent: -2 }
# im       = { coefficient: 500000000, exponent: -4 }

fn test_initial_margin_at_cap() -> Result[Unit, Str] {
  let notional := price(20000000, -2)
  let im := margin.initial_margin(notional, cfg())
  assert_eq_dec(im, price(500000000, -4), "initial margin $200k @ 25% = $50k")
}

# ---- maintenance_margin ---------------------------------------------
# $100.00 × 15% = $15.00
# = { coefficient: 150000, exponent: -4 }

fn test_maintenance_margin_standard() -> Result[Unit, Str] {
  let notional := price(10000, -2)
  let mm := margin.maintenance_margin(notional, cfg())
  assert_eq_dec(mm, price(150000, -4), "maintenance margin $100 @ 15% = $15.00")
}

# Maintenance is always less than initial for same notional.
fn test_maintenance_less_than_initial() -> Result[Unit, Str] {
  let notional := price(10000000, -2)
  let im := margin.initial_margin(notional, cfg())
  let mm := margin.maintenance_margin(notional, cfg())
  assert_true(d.lt(mm, im), "maintenance < initial")
}

# ---- pre_trade_check: passing orders --------------------------------
# qty=100, mark=$100.00 → notional=$10,000, IM=$2,500 < $50,000 → Ok

fn test_pre_trade_small_order_passes() -> Result[Unit, Str] {
  match margin.pre_trade_check(100, price(10000, -2), cfg()) {
    Ok(_) => pass(),
    Err(e) => fail("expected pass, got: " + e),
  }
}

# qty=1, mark=$250.00 → notional=$250, IM=$62.50 → Ok

fn test_pre_trade_single_share_passes() -> Result[Unit, Str] {
  match margin.pre_trade_check(1, price(25000, -2), cfg()) {
    Ok(_) => pass(),
    Err(e) => fail("expected pass, got: " + e),
  }
}

# qty=0: zero qty is allowed (degenerate but shouldn't error)

fn test_pre_trade_zero_qty_passes() -> Result[Unit, Str] {
  match margin.pre_trade_check(0, price(50000, -2), cfg()) {
    Ok(_) => pass(),
    Err(e) => fail("expected pass, got: " + e),
  }
}

# zero mark_price bypasses the check regardless of qty

fn test_pre_trade_zero_price_bypasses_check() -> Result[Unit, Str] {
  match margin.pre_trade_check(999999, d.zero(), cfg()) {
    Ok(_) => pass(),
    Err(e) => fail("zero price should bypass check, got: " + e),
  }
}

# ---- pre_trade_check: breach ----------------------------------------
# qty=1000, mark=$250.00 → notional=$250,000 → IM=$62,500 > $50,000 → Err

fn test_pre_trade_large_order_breaches() -> Result[Unit, Str] {
  match margin.pre_trade_check(1000, price(25000, -2), cfg()) {
    Ok(_) => fail("expected breach, got Ok"),
    Err(_) => pass(),
  }
}

# qty=600, mark=$500.00 → notional=$300,000 → IM=$75,000 > $50,000 → Err

fn test_pre_trade_nvda_breach() -> Result[Unit, Str] {
  match margin.pre_trade_check(600, price(50000, -2), cfg()) {
    Ok(_) => fail("expected breach, got Ok"),
    Err(_) => pass(),
  }
}

# Boundary: qty=800, mark=$250 → notional=$200,000 → IM=$50,000 (exactly at cap)
# $50,000 is NOT greater than $50,000 → Ok

fn test_pre_trade_exactly_at_cap_passes() -> Result[Unit, Str] {
  match margin.pre_trade_check(800, price(25000, -2), cfg()) {
    Ok(_) => pass(),
    Err(e) => fail("exactly at cap should pass, got: " + e),
  }
}

# qty=801, mark=$250 → notional=$200,250 → IM=$50,062.50 > $50,000 → Err

fn test_pre_trade_one_over_cap_breaches() -> Result[Unit, Str] {
  match margin.pre_trade_check(801, price(25000, -2), cfg()) {
    Ok(_) => fail("one over cap should breach"),
    Err(_) => pass(),
  }
}

# ---- Suite ----------------------------------------------------------

fn suite() -> List[Result[Unit, Str]] {
  [test_initial_margin_standard(), test_initial_margin_at_cap(), test_maintenance_margin_standard(), test_maintenance_less_than_initial(), test_pre_trade_small_order_passes(), test_pre_trade_single_share_passes(), test_pre_trade_zero_qty_passes(), test_pre_trade_zero_price_bypasses_check(), test_pre_trade_large_order_breaches(), test_pre_trade_nvda_breach(), test_pre_trade_exactly_at_cap_passes(), test_pre_trade_one_over_cap_breaches()]
}

fn run_all() -> Int {
  list.fold(suite(), 0, fn (acc :: Int, r :: Result[Unit, Str]) -> Int {
    match r {
      Ok(_) => acc,
      Err(_) => acc + 1,
    }
  })
}
