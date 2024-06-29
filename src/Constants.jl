module Constants

export ORDER_SIDE, OPTION_RIGHT

@enum ORDER_SIDE BUY_SIDE=1 SELL_SIDE=-1
@enum OPTION_RIGHT CALL=1 PUT=-1

import Base: String
String(R::OPTION_RIGHT) = R == CALL ? "C" : "P"

end