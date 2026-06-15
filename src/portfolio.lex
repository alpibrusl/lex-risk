# lex-risk — portfolio-level risk aggregation
#
# Aggregates per-position Greeks, notional, PnL, and margin across all
# positions for an account.  Callers pair each position with its current
# mark price; price discovery is left to the server layer.
#
# Effects: none.

import "std.list" as list

import "lex-money/src/decimal" as d

import "lex-positions/src/position" as pos

import "lex-positions/src/exposure" as exp

import "lex-positions/src/pnl" as pnl_mod

import "./margin" as margin

# ---- Input type -------------------------------------------------
type MarkedPosition = { position :: pos.Position, mark_price :: d.Decimal }

# ---- Per-position risk ------------------------------------------
type PositionRisk = { account :: Str, symbol :: Str, qty :: Int, delta :: Int, dollar_delta :: d.Decimal, gross_notional :: d.Decimal, unrealized_pnl :: d.Decimal, initial_margin :: d.Decimal }

# ---- Portfolio summary ------------------------------------------
type PortfolioRisk = { positions :: List[PositionRisk], net_dollar_delta :: d.Decimal, total_notional :: d.Decimal, total_unreal_pnl :: d.Decimal, total_margin :: d.Decimal }

# ---- Computation ------------------------------------------------
fn position_risk(mp :: MarkedPosition, cfg :: margin.MarginConfig) -> PositionRisk {
  let p := mp.position
  let mark := mp.mark_price
  let n := exp.gross_notional(p, mark)
  { account: p.key.account, symbol: p.key.symbol, qty: p.qty, delta: p.qty, dollar_delta: d.mul(d.from_int(p.qty), mark), gross_notional: n, unrealized_pnl: pnl_mod.unrealized_pnl(p, mark), initial_margin: margin.initial_margin(n, cfg) }
}

fn portfolio_risk(entries :: List[MarkedPosition], cfg :: margin.MarginConfig) -> PortfolioRisk {
  let prs := list.map(entries, fn (mp :: MarkedPosition) -> PositionRisk {
    position_risk(mp, cfg)
  })
  let net_dd := list.fold(prs, d.zero(), fn (acc :: d.Decimal, pr :: PositionRisk) -> d.Decimal {
    d.add(acc, pr.dollar_delta)
  })
  let tot_n := list.fold(prs, d.zero(), fn (acc :: d.Decimal, pr :: PositionRisk) -> d.Decimal {
    d.add(acc, pr.gross_notional)
  })
  let tot_up := list.fold(prs, d.zero(), fn (acc :: d.Decimal, pr :: PositionRisk) -> d.Decimal {
    d.add(acc, pr.unrealized_pnl)
  })
  let tot_m := list.fold(prs, d.zero(), fn (acc :: d.Decimal, pr :: PositionRisk) -> d.Decimal {
    d.add(acc, pr.initial_margin)
  })
  { positions: prs, net_dollar_delta: net_dd, total_notional: tot_n, total_unreal_pnl: tot_up, total_margin: tot_m }
}

