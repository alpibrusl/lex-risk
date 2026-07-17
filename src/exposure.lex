# lex-risk — counterparty exposure over open positions (#8)
#
# The agent platform's settlement trail has the same shape of problem a
# trading book has: how much OPEN exposure does one party carry to a
# counterparty — flexibility windows committed but not settled, construction
# retention held, demurrage accruing on open terminal stays. Pure aggregation
# over (counterparty, open position) pairs; limits are host-supplied data.
#
# Exact decimals throughout (lex-money): exposure is money.

import "std.str" as str

import "std.list" as list

import "lex-money/src/decimal" as d

type OpenPosition = { counterparty :: Str, kind :: Str, ref :: Str, amount :: d.Decimal }

type Exposure = { counterparty :: Str, total :: d.Decimal, count :: Int }

type ExposureLimit = { counterparty :: Str, max :: d.Decimal }

type Breach = { counterparty :: Str, total :: d.Decimal, max :: d.Decimal }

fn zero_for(counterparty :: Str) -> Exposure {
  { counterparty: counterparty, total: d.zero(), count: 0 }
}

fn add_position(exposures :: List[Exposure], p :: OpenPosition) -> List[Exposure] {
  let existing := list.head(list.filter(exposures, fn (e :: Exposure) -> Bool {
    e.counterparty == p.counterparty
  }))
  match existing {
    None => list.concat(exposures, [{ counterparty: p.counterparty, total: p.amount, count: 1 }]),
    Some(e) => list.map(exposures, fn (x :: Exposure) -> Exposure {
      if x.counterparty == p.counterparty {
        { counterparty: x.counterparty, total: d.add(x.total, p.amount), count: x.count + 1 }
      } else {
        x
      }
    }),
  }
}

# A scale-invariant Int sort key: the amount in cents (sub-cent precision
# truncates — this orders exposures, it never settles them).
fn to_cents(x :: d.Decimal) -> Int {
  let n := d.normalize(x)
  if n.exponent >= -2 {
    n.coefficient * d.pow10(n.exponent + 2)
  } else {
    n.coefficient / d.pow10(0 - (n.exponent + 2))
  }
}

# Aggregate open positions per counterparty, largest exposure first.
fn exposure_by_counterparty(positions :: List[OpenPosition]) -> List[Exposure] {
  let agg := list.fold(positions, [], add_position)
  list.sort_by(agg, fn (e :: Exposure) -> Int {
    0 - to_cents(e.total)
  })
}

# The limit that applies to a counterparty: its own row wins, else the
# "default" row, else none (unlimited).
fn limit_for(limits :: List[ExposureLimit], counterparty :: Str) -> Option[d.Decimal] {
  let own := list.head(list.filter(limits, fn (l :: ExposureLimit) -> Bool {
    l.counterparty == counterparty
  }))
  match own {
    Some(l) => Some(l.max),
    None => match list.head(list.filter(limits, fn (l :: ExposureLimit) -> Bool {
      l.counterparty == "default"
    })) {
      Some(l) => Some(l.max),
      None => None,
    },
  }
}

# Every counterparty whose open exposure exceeds its applicable limit.
fn breaches(exposures :: List[Exposure], limits :: List[ExposureLimit]) -> List[Breach] {
  list.fold(exposures, [], fn (acc :: List[Breach], e :: Exposure) -> List[Breach] {
    match limit_for(limits, e.counterparty) {
      None => acc,
      Some(mx) => if d.gt(e.total, mx) {
        list.concat(acc, [{ counterparty: e.counterparty, total: e.total, max: mx }])
      } else {
        acc
      },
    }
  })
}

# The ARM-style gate: a counterparty in breach is not in good standing for
# NEW exposure, whatever its interaction history says.
fn under_limit(exposures :: List[Exposure], limits :: List[ExposureLimit], counterparty :: Str) -> Bool {
  let e := match list.head(list.filter(exposures, fn (x :: Exposure) -> Bool {
    x.counterparty == counterparty
  })) {
    Some(x) => x,
    None => zero_for(counterparty),
  }
  match limit_for(limits, counterparty) {
    None => true,
    Some(mx) => not d.gt(e.total, mx),
  }
}

