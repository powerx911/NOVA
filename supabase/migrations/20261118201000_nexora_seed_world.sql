insert into nexora.market_listings(id,seller_uid,seller_name,item_id,quantity,remaining_qty,unit_price,status)
values
('seed_silicon_ore','SYSTEM','NEXORA','silicon_ore',250,250,35,'active'),
('seed_copper_wire','SYSTEM','NEXORA','copper_wire',250,250,28,'active'),
('seed_energy_cells','SYSTEM','NEXORA','energy_cells',200,200,45,'active'),
('seed_crude_alloy','SYSTEM','NEXORA','crude_alloy',200,200,40,'active'),
('seed_carbon_fiber','SYSTEM','NEXORA','carbon_fiber',160,160,55,'active'),
('seed_rare_minerals','SYSTEM','NEXORA','rare_minerals',140,140,70,'active')
on conflict(id) do nothing;

insert into nexora.world_events(id,title_ar,title_en,description_ar,description_en,effect_type,target_item_id,affected_sectors,price_multiplier,revenue_multiplier,tax_delta,stack_group,starts_at,ends_at,active)
values
('evt_silicon_boom','طفرة الطلب على الرقائق','Silicon & Microchip Demand Surge','ارتفاع الطلب العالمي على أشباه الموصلات يرفع تقييم الرقائق (+18%) وعوائد شركات التقنية (+15%).','Global semiconductor demand boosts Microchip index (+18%) and Tech company yields (+15%).','demand_surge','microchips','["tech"]'::jsonb,1.18,1.15,0,'sector_tech',now(),now()+interval '24 hours',true),
('evt_tax_holiday','حافز التجارة الحرة','Free Trade Tax Incentive','خفض مؤقت لضريبة معاملات السوق بمقدار 1% مع دفعة تشجيعية لقطاع التجارة (+8%).','Temporary 1% market transaction tax cut with a +8% Trade sector liquidity boost.','tax_cut','','["trade"]'::jsonb,1.0,1.08,-0.01,'fiscal_policy',now(),now()+interval '24 hours',true),
('evt_logistics_boom','ازدهار النقل والإمداد','Global Logistics & Freight Boom','تسارع حركة الشحن العالمية يرفع قيمة طائرات الشحن (+14%) وعوائد النقل والتجارة (+16%).','Surging freight corridors boost Logistics Drone valuations (+14%) and Logistics/Trade output (+16%).','logistics_boom','logistics_drone','["logistics","trade"]'::jsonb,1.14,1.16,0,'sector_logistics',now(),now()+interval '24 hours',true)
on conflict(id) do nothing;
