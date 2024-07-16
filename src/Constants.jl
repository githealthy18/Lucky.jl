module Constants

export ORDER_SIDE, BUY_SIDE, SELL_SIDE
export OPTION_RIGHT, CALL, PUT

@enum ORDER_SIDE BUY_SIDE=1 SELL_SIDE=-1
@enum OPTION_RIGHT CALL=1 PUT=-1

import Base: String, convert
String(R::OPTION_RIGHT) = R == CALL ? "C" : "P"
convert(T::Type{Bool}, R::OPTION_RIGHT) = R == CALL ? true : false

end