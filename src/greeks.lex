# lex-risk — equity position Greeks
#
# For equity (stock) positions, delta is 1 per unit held, so the
# position delta equals the signed qty.  Dollar delta is the net $ move
# per $1 change in the underlying — qty × mark_price (signed: negative
# when net short).
#
# Effects: none.

import "lex-money/src/decimal" as d

import "lex-positions/src/position" as pos

type EquityGreeks = {
  delta        :: Int,       # signed qty: long > 0, short < 0, flat = 0
  dollar_delta :: d.Decimal, # qty × mark_price (negative = net short)
}

fn equity_greeks(position :: pos.Position, mark_price :: d.Decimal) -> EquityGreeks {
  { delta: position.qty, dollar_delta: d.mul(d.from_int(position.qty), mark_price) }
}

fn abs_delta(g :: EquityGreeks) -> Int {
  if g.delta < 0 { 0 - g.delta } else { g.delta }
}
