# lex-risk

Portfolio risk aggregation for the [Lex language](https://github.com/alpibrusl/lex-lang).

Computes equity Greeks, gross notional, unrealized PnL, and Reg-T style initial margin across a portfolio of positions. All arithmetic is exact `Decimal` from [lex-money](https://github.com/alpibrusl/lex-money). Pure — no effects.

## What it ships

- **`src/greeks.lex`** — `EquityGreeks` (`delta` = signed qty, `dollar_delta` = qty × mark). For equity positions, delta is 1 per unit.
- **`src/margin.lex`** — `MarginConfig` (initial rate 25%, maintenance rate 15%, per-order cap $50,000). `pre_trade_check` rejects an order whose initial margin (qty × mark × rate) exceeds the cap. Zero mark price bypasses the check. Returns `Result[Unit, Str]`.
- **`src/portfolio.lex`** — `portfolio_risk` aggregates a `List[MarkedPosition]` into `PortfolioRisk`: per-position Greeks + notional + unrealized PnL + initial margin, plus portfolio-level sums (`net_dollar_delta`, `total_notional`, `total_unreal_pnl`, `total_margin`).

## Usage

```lex
import "lex-risk/src/margin"    as margin
import "lex-risk/src/portfolio" as portfolio

# Pre-trade margin check
let cfg := margin.default_margin_config()   # 25% Reg-T, $50k cap
match margin.pre_trade_check(qty, mark_price, cfg) {
  Err(reason) => # reject
  Ok(_)       => # proceed to pre-trade gate
}

# Portfolio risk snapshot
let entries := list.map(positions, fn (p) -> portfolio.MarkedPosition {
  { position: p, mark_price: lookup_mark(p.key.symbol) }
})
let risk := portfolio.portfolio_risk(entries, cfg)
```

Run the worked example:

```sh
lex run examples/margin_breach.lex main
```

## Effects

All modules are pure (no effects). Mark prices are supplied by the caller; price discovery is the server layer's responsibility.

## Dependencies

- **lex-money** — `Decimal` arithmetic.
- **lex-positions** — `Position`, `exposure.gross_notional`, `pnl.unrealized_pnl`.

---

Built under the principles of [Trust Without Comprehension](https://alpibru.com/manifesto).
