begin;
select plan(5);

select results_eq($$select gateway_fee_sen, platform_fee_sen, host_receives_sen from payments.compute_fees(36000)$$,
  $$values (540, 3600, 31860)$$, 'compute_fees_36000_gives_540_3600_31860 (12 guests at RM30)');
select results_eq($$select gateway_fee_sen, platform_fee_sen, host_receives_sen from payments.compute_fees(1010)$$,
  $$values (15, 101, 894)$$, 'compute_fees_rounds_half_up_at_odd_amounts (1010 sen)');
select results_eq($$select gateway_fee_sen, platform_fee_sen, host_receives_sen from payments.compute_fees(100)$$,
  $$values (2, 10, 88)$$, 'a gateway fee of exactly 1.5 sen rounds up to 2');
select results_eq($$select gateway_fee_sen, platform_fee_sen, host_receives_sen from payments.compute_fees(5)$$,
  $$values (0, 1, 4)$$, 'a platform fee of exactly 0.5 sen rounds up to 1');
select results_eq($$select gateway_fee_sen, platform_fee_sen, host_receives_sen from payments.compute_fees(0)$$,
  $$values (0, 0, 0)$$, 'nothing paid, nothing charged');

select * from finish();
rollback;
