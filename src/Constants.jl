module Constants

export ORDER_SIDE, ENVIRONMENT

@enum ORDER_SIDE BUY_SIDE=1 SELL_SIDE=-1

@enum ENVIRONMENT LOCAL=1 TEST=2 PROD=3

end