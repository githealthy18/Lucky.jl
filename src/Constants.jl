export ORDER_SIDE, BUY_SIDE, SELL_SIDE
export ACTION, OPEN, CLOSE
export OPTION_RIGHT, CALL, PUT
export DIRECTION
export up, down, flat

@enum DIRECTION up=1 down=-1 flat=0

@enum ORDER_SIDE BUY_SIDE=1 SELL_SIDE=-1
@enum ACTION OPEN=1 CLOSE=-1
@enum OPTION_RIGHT CALL=1 PUT=-1

import Base: String, convert, !
String(R::OPTION_RIGHT) = R == CALL ? "C" : "P"
convert(T::Type{Bool}, R::OPTION_RIGHT) = R == CALL ? true : false
convert(T::Type{OPTION_RIGHT}, b::Bool) = b ? CALL : PUT
convert(T::Type{OPTION_RIGHT}, s::String) = s == "C" ? CALL : PUT
!(x::OPTION_RIGHT) = x == CALL ? PUT : CALL


String(O::ORDER_SIDE) = O == BUY_SIDE ? "BUY" : "SELL"
convert(T::Type{ORDER_SIDE}, s::String) = s == "BUY" ? BUY_SIDE : SELL_SIDE
!(x::ORDER_SIDE) = x == BUY_SIDE ? SELL_SIDE : BUY_SIDE