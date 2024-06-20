module Constants

export ORDER_SIDE, ENVIRONMENT, REGISTER_REQUEST_SUBJECT, BOOT_STRAP_SUBJECT, COMPLETED_REQUESTS, CONNECTIONS_SUB
export DEFAULT_IB_SERVICE, ACCOUNT_SUB, ERROR_SUB, NEXT_VALID_ID_SUB, TICK_PRICE_SUB, TICK_SIZE_SUB
export TICK_OPTION_COMPUTATION_SUB, HISTORICAL_DATA_SUB, SEC_DEF_OPTIONAL_PARAM_SUB
export DEFAULT_IB_SERVICE_MANAGER, DEFAULT_REQUEST_MANAGER

using Lucky
using Lucky.ProcessMsgs
using Rocket

@enum ORDER_SIDE BUY_SIDE=1 SELL_SIDE=-1

@enum ENVIRONMENT LOCAL=1 TEST=2 PROD=3

const REGISTER_REQUEST_SUB = Subject(RegisterRequest)

const BOOTSTRAP_SUB = Subject(BootStrapSystem)

const COMPLETED_REQUESTS_SUB = Subject(CompleteRequestMsg)

const CONNECTION_SUB = Subject(ConnectionMsg)


const DEFAULT_IB_SERVICE = Lucky.service(Val(:interactivebrokers))


const ACCOUNT_SUB = Lucky.feed(DEFAULT_IB_SERVICE, :accountSummary)
const ERROR_SUB = Lucky.feed(DEFAULT_IB_SERVICE, :error)
const NEXT_VALID_ID_SUB = Lucky.feed(DEFAULT_IB_SERVICE, :nextValidId)
const TICK_PRICE_SUB = Lucky.feed(DEFAULT_IB_SERVICE, :tickPrice)
const TICK_SIZE_SUB = Lucky.feed(DEFAULT_IB_SERVICE, :tickSize)
const TICK_OPTION_COMPUTATION_SUB = Lucky.feed(DEFAULT_IB_SERVICE, :tickOptionComputation)
const HISTORICAL_DATA_SUB = Lucky.feed(DEFAULT_IB_SERVICE, :historicalData)
const SEC_DEF_OPTIONAL_PARAM_SUB = Lucky.feed(DEFAULT_IB_SERVICE, :securityDefinitionOptionalParameter)

const DEFAULT_IB_SERVICE_MANAGER = ServiceManager(DEFAULT_IB_SERVICE, nothing)

subscribe!(BOOTSTRAP_SUBJECT, DEFAULT_IB_SERVICE_MANAGER)

const DEFAULT_REQUEST_MANAGER = RequestManager(nothing, 1, BitArray{1}(), Vector{Pair{<:Function, <:Tuple}}(), Vector{Pair{<:Function, <:Tuple}}())
subscribe!(REGISTER_REQUEST_SUB, DEFAULT_REQUEST_MANAGER)
subscribe!(BOOTSTRAP_SUB, DEFAULT_REQUEST_MANAGER)
subscribe!(CONNECTION_SUB, DEFAULT_REQUEST_MANAGER)
subscribe!(COMPLETED_REQUESTS_SUB, DEFAULT_REQUEST_MANAGER)

end