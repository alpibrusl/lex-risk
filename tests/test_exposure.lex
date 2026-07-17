# tests for src/exposure.lex — counterparty exposure over open positions (#8).

import "std.str" as str

import "std.list" as list

import "lex-money/src/decimal" as d

import "../src/exposure" as ex

fn assert_true(cond :: Bool, label :: Str) -> Result[Unit, Str] {
  if cond {
    Ok(())
  } else {
    Err(label)
  }
}

fn dec(s :: Str) -> d.Decimal {
  match d.parse(s) {
    Some(v) => v,
    None => d.zero(),
  }
}

fn positions() -> List[ex.OpenPosition] {
  [{ counterparty: "sub-ferro", kind: "retention", ref: "OBRA-1|M1", amount: dec("600.00") }, { counterparty: "sub-ferro", kind: "retention", ref: "OBRA-1|M2", amount: dec("900.00") }, { counterparty: "carrier-b", kind: "demurrage_open", ref: "CONT-1", amount: dec("85.00") }]
}

fn test_aggregation_is_exact_and_sorted() -> Result[Unit, Str] {
  let exps := ex.exposure_by_counterparty(positions())
  match list.head(exps) {
    None => Err("no exposures"),
    Some(top) => {
      let top_ok := top.counterparty == "sub-ferro" and d.to_str(top.total) == "1500.00" and top.count == 2
      let second_ok := match list.head(list.tail(exps)) {
        Some(s) => s.counterparty == "carrier-b" and d.to_str(s.total) == "85.00",
        None => false,
      }
      assert_true(top_ok and second_ok, str.concat("agg wrong: top=", d.to_str(top.total)))
    },
  }
}

fn test_limits_specific_beats_default() -> Result[Unit, Str] {
  let limits := [{ counterparty: "default", max: dec("50.00") }, { counterparty: "sub-ferro", max: dec("2000.00") }]
  let exps := ex.exposure_by_counterparty(positions())
  let ferro_ok := ex.under_limit(exps, limits, "sub-ferro")
  let carrier_breach := not ex.under_limit(exps, limits, "carrier-b")
  let brs := ex.breaches(exps, limits)
  let one_breach := list.len(brs) == 1 and match list.head(brs) {
    Some(b) => b.counterparty == "carrier-b",
    None => false,
  }
  assert_true(ferro_ok and carrier_breach and one_breach, "limit resolution wrong")
}

fn test_unknown_counterparty_without_limits_is_clean() -> Result[Unit, Str] {
  let exps := ex.exposure_by_counterparty(positions())
  assert_true(ex.under_limit(exps, [], "nobody"), "no limits must mean unlimited")
}

fn run_all() -> [io, sql, fs_read, fs_write, time, crypto, random, net, concurrent, llm, proc] Unit {
  let results := [test_aggregation_is_exact_and_sorted(), test_limits_specific_beats_default(), test_unknown_counterparty_without_limits_is_clean()]
  let failures := list.fold(results, [], fn (acc :: List[Str], r :: Result[Unit, Str]) -> List[Str] {
    match r {
      Ok(_) => acc,
      Err(m) => list.concat(acc, [m]),
    }
  })
  if list.is_empty(failures) {
    ()
  } else {
    let __boom := 1 / 0
    ()
  }
}

