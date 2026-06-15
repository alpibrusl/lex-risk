# lex-risk — Reg-T style margin configuration and pre-trade checks
#
# MarginConfig captures three margin parameters:
#   initial_rate     — fraction of notional required at order entry (0.25 = 25%)
#   maintenance_rate — fraction required to maintain a position     (0.15 = 15%)
#   max_order_margin — hard per-order initial-margin cap
#
# pre_trade_check rejects an order whose initial margin requirement
# (qty × mark_price × initial_rate) exceeds max_order_margin.
# A zero mark_price is treated as "price unknown" and bypasses the check.
#
# Effects: none.

import "lex-money/src/decimal" as d

import "lex-positions/src/position" as pos

type MarginConfig = { initial_rate :: d.Decimal, maintenance_rate :: d.Decimal, max_order_margin :: d.Decimal }

fn default_margin_config() -> MarginConfig {
  { initial_rate: d.decimal(25, -2), maintenance_rate: d.decimal(15, -2), max_order_margin: d.decimal(5000000000, -2) }
}

fn initial_margin(notional :: d.Decimal, cfg :: MarginConfig) -> d.Decimal {
  d.mul(notional, cfg.initial_rate)
}

fn maintenance_margin(notional :: d.Decimal, cfg :: MarginConfig) -> d.Decimal {
  d.mul(notional, cfg.maintenance_rate)
}

# Returns Ok(()) when the order passes, Err(reason) when it breaches.
fn pre_trade_check(qty :: Int, mark_price :: d.Decimal, cfg :: MarginConfig) -> Result[Unit, Str] {
  if d.is_zero(mark_price) {
    Ok(())
  } else {
    let notional := d.mul(d.from_int(qty), mark_price)
    let im := initial_margin(notional, cfg)
    if d.gt(im, cfg.max_order_margin) {
      Err("order initial margin " + pos.decimal_to_str(im) + " exceeds limit " + pos.decimal_to_str(cfg.max_order_margin))
    } else {
      Ok(())
    }
  }
}

