# lex-risk

Portfolio risk aggregation for Lex. Pure — no effects.

Computes equity Greeks (delta), gross notional, unrealized PnL, and Reg-T initial margin across a portfolio of positions. All arithmetic is exact `Decimal` from `lex-money`. Mark prices are supplied by the caller — price discovery is the server layer's responsibility.

**Current scope:** equity delta is 1.0 per share. Options pricing (Black-Scholes delta) is tracked in [issue #2](https://github.com/alpibrusl/lex-risk/issues/2).

---

## Modules

### `greeks.lex` — position-level Greeks

```lex
type EquityGreeks = { delta :: d.Decimal, dollar_delta :: d.Decimal }

equity_greeks(position, mark_price)
# delta       = signed qty (positive = long, negative = short)
# dollar_delta = qty × mark_price
```

### `margin.lex` — Reg-T margin + pre-trade check

```lex
type MarginConfig = { initial_rate :: d.Decimal, maintenance_rate :: d.Decimal, max_order_margin :: d.Decimal }

default_margin_config()
# initial_rate     = 25%
# maintenance_rate = 15%
# max_order_margin = $50,000,000

pre_trade_check(qty, mark_price, config)
# initial margin = qty × mark × 0.25
# returns Err if that exceeds max_order_margin
# zero mark_price bypasses the check (no market data available)
```

### `portfolio.lex` — portfolio-level aggregation

```lex
portfolio_risk(marked_positions, margin_config)
# Per position: delta, dollar_delta, gross_notional, unrealized_pnl, initial_margin
# Portfolio totals: net_dollar_delta, total_notional, total_unreal_pnl, total_margin
```

---

## Usage

```lex
import "lex-risk/src/margin"    as margin
import "lex-risk/src/portfolio" as portfolio

# Pre-trade margin check
match margin.pre_trade_check(qty, mark, margin.default_margin_config()) {
  Err(reason) => # reject
  Ok(_)       => # pass to pre-trade gate
}

# Portfolio snapshot
let marked := list.map(positions, fn (p) -> portfolio.MarkedPosition {
  { position: p, mark_price: mock.get_reference_price(p.key.symbol) }
})
let risk := portfolio.portfolio_risk(marked, margin.default_margin_config())
```

---

## In the stack

```
lex-money · lex-positions
    ↓
lex-risk  ←  risk analytics
    ↓
lex-finance · lex-oms
```

`lex-oms` calls `portfolio_risk` on every `GET /risk` request. `lex-finance` pre-trade gate uses `pre_trade_check` as the margin layer.

---

## What's next

Options pricing (Black-Scholes) would make `equity_greeks` return true delta < 1.0 for option positions, enabling the auto-hedging use case: Lex computes the hedge quantity deterministically, the LLM agent submits it. See [issue #2](https://github.com/alpibrusl/lex-risk/issues/2).

---

## Install

```toml
[dependencies]
"lex-risk" = { git = "https://github.com/alpibrusl/lex-risk" }
```
