# lex-risk example — margin breach rejection
#
# An order exceeding the per-order initial-margin cap is rejected by
# pre_trade_check before it touches the exchange — not a runtime
# convention, a typed gate.
#
# Scenario:
#   Account ACC1 holds NVDA +200 @ $500.  A new order for 600 shares
#   at $500 would cost $300,000 in notional — 25% initial margin =
#   $75,000, which breaches the $50,000 per-order cap.  An order for
#   200 shares at $400 (notional $80,000, IM $20,000) sails through.
#
# Run:
#   lex run --allow-effects io \
#           examples/margin_breach.lex main

import "std.io" as io

import "lex-money/src/decimal" as d

import "lex-positions/src/position" as pos

import "../src/margin" as margin
import "../src/portfolio" as port

fn price(c :: Int, e :: Int) -> d.Decimal {
  { coefficient: c, exponent: e }
}

fn section(title :: Str) -> [io] Unit {
  let line := "─────────────────────────────────────────"
  let __lex_discard_1 := io.print("")
  let __lex_discard_2 := io.print("  " + title)
  io.print(line)
}

fn show_check(label :: Str, qty :: Int, mark :: d.Decimal, cfg :: margin.MarginConfig) -> [io] Unit {
  let __lex_discard_3 := io.print("  " + label)
  match margin.pre_trade_check(qty, mark, cfg) {
    Ok(_) => io.print("    → ACCEPTED  (initial margin within $50,000 cap)"),
    Err(reason) => io.print("    → REJECTED  " + reason),
  }
}

fn nvda_position() -> pos.Position {
  { key: { account: "ACC1", symbol: "NVDA" }, qty: 200, avg_cost: price(50000, -2), realized_pnl: d.zero() }
}

fn show_portfolio(cfg :: margin.MarginConfig) -> [io] Unit {
  let entries := [{ position: nvda_position(), mark_price: price(50000, -2) }]
  let risk := port.portfolio_risk(entries, cfg)
  match list.head(risk.positions) {
    None => io.print("  (empty)"),
    Some(pr) => {
      let __lex_discard_4 := io.print("  symbol          " + pr.symbol)
      let __lex_discard_5 := io.print("  qty             " + int_str(pr.qty))
      let __lex_discard_6 := io.print("  delta           " + int_str(pr.delta))
      let __lex_discard_7 := io.print("  dollar_delta    $" + pos.decimal_to_str(pr.dollar_delta))
      let __lex_discard_8 := io.print("  gross_notional  $" + pos.decimal_to_str(pr.gross_notional))
      let __lex_discard_9 := io.print("  unrealized_pnl  $" + pos.decimal_to_str(pr.unrealized_pnl))
      io.print("  initial_margin  $" + pos.decimal_to_str(pr.initial_margin))
    },
  }
}

fn int_str(n :: Int) -> Str {
  if n < 0 {
    "-" + pos.decimal_to_str(d.from_int(0 - n))
  } else {
    pos.decimal_to_str(d.from_int(n))
  }
}

import "std.list" as list
import "std.int" as int

fn main() -> [io] Unit {
  let cfg := margin.default_margin_config()

  let __lex_discard_a := io.print("")
  let __lex_discard_b := io.print("  lex-risk — margin breach example")
  let __lex_discard_c := io.print("  Reg-T: 25% initial margin, $50,000 per-order cap")

  let __lex_discard_d := section("Current portfolio — NVDA +200 @ $500")
  let __lex_discard_e := show_portfolio(cfg)

  let __lex_discard_f := section("Pre-trade check — incoming orders")

  # Order 1: 600 shares @ $500  →  notional $300,000  →  IM $75,000  →  BREACH
  let __lex_discard_g := show_check("BUY 600 NVDA @ $500.00  (notional $300,000  IM $75,000)", 600, price(50000, -2), cfg)

  # Order 2: 200 shares @ $400  →  notional $80,000   →  IM $20,000  →  PASS
  let __lex_discard_h := show_check("BUY 200 NVDA @ $400.00  (notional $80,000   IM $20,000)", 200, price(40000, -2), cfg)

  # Order 3: 800 shares @ $250  →  notional $200,000  →  IM $50,000  →  exactly at cap, PASS
  let __lex_discard_i := show_check("BUY 800 NVDA @ $250.00  (notional $200,000  IM $50,000  — at cap)", 800, price(25000, -2), cfg)

  # Order 4: 801 shares @ $250  →  notional $200,250  →  IM $50,062.50  →  one share over, BREACH
  show_check("BUY 801 NVDA @ $250.00  (notional $200,250  IM $50,062  — one share over)", 801, price(25000, -2), cfg)
}
