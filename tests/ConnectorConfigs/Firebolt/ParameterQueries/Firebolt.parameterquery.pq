let
    ASource = Firebolt.Contents("developer", "petro_test", "petro_test_pbi", "staging"),
    Source = ASource{[Name="public"]}[Data],
    NycTaxiGreen_Table = Source{[Name="NycTaxiGreen"]}[Data],
    TaxiZoneLookup_Table = Source{[Name="TaxiZoneLookup"]}[Data]
in
    [taxi_table = NycTaxiGreen_Table, zone_table = TaxiZoneLookup_Table]
