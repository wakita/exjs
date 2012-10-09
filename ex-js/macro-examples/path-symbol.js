expression 乗り換え経路 {
    symbol: 路線, 出発地, 到着地;

    { 乗り換え経路 [# 出発地 -> 到着地 : 路線 #] ...
      => [{ from: 出発地, to: 到着地, via: 路線 }, ...] }
}

乗り換え経路 新宿->東京 : 中央線
          東京->京都 : 新幹線;