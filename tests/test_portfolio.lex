# Tests for portfolio — position_risk and portfolio_risk aggregation.
#
# All tests are pure (no effects).
#
# Position arithmetic:
#   AAPL long  100 @ $175.00  →  notional $17,500  IM $4,375.00
#   MSFT short  50 @ $420.00  →  notional $21,000  IM $5,250.00
#   Net dollar delta: $17,500 − $21,000 = −$3,500  (net short bias)
#   Total notional: $17,500 + $21,000 = $38,500
#   Total margin:    $4,375 + $5,250  =  $9,625

import "std.list" as list

import "lex-money/src/decimal" as d

import "lex-positions/src/position" as pos

import "../src/margin" as margin
import "../src/portfolio" as port

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

fn cfg() -> margin.MarginConfig {
  margin.default_margin_config()
}

# Positions: avg_cost = mark_price so unrealized PnL is zero everywhere.
fn aapl_long() -> pos.Position {
  { key: { account: "ACC1", symbol: "AAPL" }, qty: 100, avg_cost: price(17500, -2), realized_pnl: d.zero() }
}

fn msft_short() -> pos.Position {
  { key: { account: "ACC1", symbol: "MSFT" }, qty: 0 - 50, avg_cost: price(42000, -2), realized_pnl: d.zero() }
}

fn aapl_mark() -> d.Decimal { price(17500, -2) }
fn msft_mark() -> d.Decimal { price(42000, -2) }

# ---- position_risk for a single long position -----------------------

fn test_position_risk_symbol() -> Result[Unit, Str] {
  let pr := port.position_risk({ position: aapl_long(), mark_price: aapl_mark() }, cfg())
  assert_true(pr.symbol == "AAPL", "symbol = AAPL")
}

fn test_position_risk_qty() -> Result[Unit, Str] {
  let pr := port.position_risk({ position: aapl_long(), mark_price: aapl_mark() }, cfg())
  assert_eq_int(pr.qty, 100, "qty = 100")
}

fn test_position_risk_delta_long() -> Result[Unit, Str] {
  let pr := port.position_risk({ position: aapl_long(), mark_price: aapl_mark() }, cfg())
  assert_eq_int(pr.delta, 100, "long delta = qty")
}

fn test_position_risk_dollar_delta_long() -> Result[Unit, Str] {
  let pr := port.position_risk({ position: aapl_long(), mark_price: aapl_mark() }, cfg())
  # 100 × $175.00 = { coefficient: 1750000, exponent: -2 }
  assert_eq_dec(pr.dollar_delta, price(1750000, -2), "dollar delta = $17,500")
}

fn test_position_risk_gross_notional_long() -> Result[Unit, Str] {
  let pr := port.position_risk({ position: aapl_long(), mark_price: aapl_mark() }, cfg())
  assert_eq_dec(pr.gross_notional, price(1750000, -2), "gross notional = $17,500")
}

fn test_position_risk_unrealized_pnl_zero() -> Result[Unit, Str] {
  let pr := port.position_risk({ position: aapl_long(), mark_price: aapl_mark() }, cfg())
  assert_true(d.is_zero(pr.unrealized_pnl), "unrealized pnl = 0 (avg_cost = mark)")
}

fn test_position_risk_initial_margin_long() -> Result[Unit, Str] {
  let pr := port.position_risk({ position: aapl_long(), mark_price: aapl_mark() }, cfg())
  # $17,500 × 0.25 = { coefficient: 43750000, exponent: -4 } = $4,375.00
  assert_eq_dec(pr.initial_margin, price(43750000, -4), "initial margin = $4,375")
}

# ---- position_risk for a short position -----------------------------

fn test_position_risk_delta_short() -> Result[Unit, Str] {
  let pr := port.position_risk({ position: msft_short(), mark_price: msft_mark() }, cfg())
  assert_eq_int(pr.delta, 0 - 50, "short delta = -50")
}

fn test_position_risk_dollar_delta_short() -> Result[Unit, Str] {
  let pr := port.position_risk({ position: msft_short(), mark_price: msft_mark() }, cfg())
  # -50 × $420.00 = { coefficient: -2100000, exponent: -2 }
  assert_eq_dec(pr.dollar_delta, price(0 - 2100000, -2), "dollar delta = -$21,000")
}

fn test_position_risk_gross_notional_short() -> Result[Unit, Str] {
  let pr := port.position_risk({ position: msft_short(), mark_price: msft_mark() }, cfg())
  # |−50| × $420.00 = { coefficient: 2100000, exponent: -2 }  (positive)
  assert_eq_dec(pr.gross_notional, price(2100000, -2), "gross notional short = $21,000")
}

fn test_position_risk_initial_margin_short() -> Result[Unit, Str] {
  let pr := port.position_risk({ position: msft_short(), mark_price: msft_mark() }, cfg())
  # $21,000 × 0.25 = { coefficient: 52500000, exponent: -4 } = $5,250.00
  assert_eq_dec(pr.initial_margin, price(52500000, -4), "initial margin short = $5,250")
}

# ---- portfolio_risk: mixed long + short -----------------------------

fn mixed_entries() -> List[port.MarkedPosition] {
  [{ position: aapl_long(), mark_price: aapl_mark() }, { position: msft_short(), mark_price: msft_mark() }]
}

fn test_portfolio_position_count() -> Result[Unit, Str] {
  let pr := port.portfolio_risk(mixed_entries(), cfg())
  assert_eq_int(list.len(pr.positions), 2, "portfolio has 2 positions")
}

fn test_portfolio_net_dollar_delta() -> Result[Unit, Str] {
  let pr := port.portfolio_risk(mixed_entries(), cfg())
  # $17,500 + (−$21,000) = −$3,500  →  { coefficient: -350000, exponent: -2 }
  assert_eq_dec(pr.net_dollar_delta, price(0 - 350000, -2), "net dollar delta = -$3,500")
}

fn test_portfolio_net_delta_is_negative() -> Result[Unit, Str] {
  let pr := port.portfolio_risk(mixed_entries(), cfg())
  assert_true(d.is_negative(pr.net_dollar_delta), "net delta negative = more short than long")
}

fn test_portfolio_total_notional() -> Result[Unit, Str] {
  let pr := port.portfolio_risk(mixed_entries(), cfg())
  # $17,500 + $21,000 = $38,500  →  { coefficient: 3850000, exponent: -2 }
  assert_eq_dec(pr.total_notional, price(3850000, -2), "total notional = $38,500")
}

fn test_portfolio_total_unrealized_pnl_zero() -> Result[Unit, Str] {
  let pr := port.portfolio_risk(mixed_entries(), cfg())
  assert_true(d.is_zero(pr.total_unreal_pnl), "total unrealized pnl = 0")
}

fn test_portfolio_total_margin() -> Result[Unit, Str] {
  let pr := port.portfolio_risk(mixed_entries(), cfg())
  # $4,375 + $5,250 = $9,625  →  { coefficient: 96250000, exponent: -4 }
  assert_eq_dec(pr.total_margin, price(96250000, -4), "total margin = $9,625")
}

# ---- portfolio_risk: empty -----------------------------------------

fn test_empty_portfolio() -> Result[Unit, Str] {
  let pr := port.portfolio_risk([], cfg())
  match assert_eq_int(list.len(pr.positions), 0, "no positions") {
    Err(e) => Err(e),
    Ok(_) => match assert_true(d.is_zero(pr.net_dollar_delta), "net dd = 0") {
      Err(e) => Err(e),
      Ok(_) => match assert_true(d.is_zero(pr.total_notional), "notional = 0") {
        Err(e) => Err(e),
        Ok(_) => assert_true(d.is_zero(pr.total_margin), "margin = 0"),
      },
    },
  }
}

# ---- Suite ----------------------------------------------------------

fn suite() -> List[Result[Unit, Str]] {
  [test_position_risk_symbol(), test_position_risk_qty(), test_position_risk_delta_long(), test_position_risk_dollar_delta_long(), test_position_risk_gross_notional_long(), test_position_risk_unrealized_pnl_zero(), test_position_risk_initial_margin_long(), test_position_risk_delta_short(), test_position_risk_dollar_delta_short(), test_position_risk_gross_notional_short(), test_position_risk_initial_margin_short(), test_portfolio_position_count(), test_portfolio_net_dollar_delta(), test_portfolio_net_delta_is_negative(), test_portfolio_total_notional(), test_portfolio_total_unrealized_pnl_zero(), test_portfolio_total_margin(), test_empty_portfolio()]
}

fn run_all() -> Int {
  list.fold(suite(), 0, fn (acc :: Int, r :: Result[Unit, Str]) -> Int {
    match r {
      Ok(_) => acc,
      Err(_) => acc + 1,
    }
  })
}
