port module Main exposing (..)

import Array exposing (Array)
import Browser
import Browser.Events as BrowserEvent
import FormatNumber as F
import FormatNumber.Locales as F
import Html exposing (Html)
import Html.Attributes as HA
import Html.Events as Event
import Json.Decode as Decode
import Json.Decode.Pipeline as Decode
import Json.Encode as Encode



-- PORTS


port initFlux : Encode.Value -> Cmd msg


port setSettings : Encode.Value -> Cmd msg


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type alias Model =
    { isOpen : Bool
    , settings : Settings
    }


type alias Settings =
    { viscosity : Float
    , velocityDissipation : Float
    , startingPressure : Float
    , fluidSize : Int
    , fluidSimulationFrameRate : Int
    , diffusionIterations : Int
    , pressureIterations : Int
    , colorScheme : ColorScheme
    , lineLength : Float
    , lineWidth : Float
    , lineBeginOffset : Float
    , lineFadeOutLength : Float
    , springVariance : Float
    , gridSpacing : Int
    , viewScale : Float
    , noiseChannels : Array Noise
    }


type ColorScheme
    = Plasma
    | Peacock
    | Poolside
    | Pollen


type alias Noise =
    { scale : Float
    , multiplier : Float
    , offset1 : Float
    , offset2 : Float
    , offsetIncrement : Float
    }


defaultSettings : Settings
defaultSettings =
    { viscosity = 5.0
    , velocityDissipation = 0.0
    , startingPressure = 0.0
    , fluidSize = 128
    , fluidSimulationFrameRate = 60
    , colorScheme = Peacock
    , diffusionIterations = 4
    , pressureIterations = 20
    , lineLength = 300.0
    , lineWidth = 5.0
    , lineBeginOffset = 0.5
    , lineFadeOutLength = 0.005
    , springVariance = 0.47
    , viewScale = 1.6
    , gridSpacing = 14
    , noiseChannels =
        Array.fromList
            [ { scale = 2.3 -- 2.3
              , multiplier = 1.0 -- 0.9
              , offset1 = 0.0
              , offset2 = 0.0
              , offsetIncrement = 0.002
              }
            , { scale = 13.8
              , multiplier = 0.7
              , offset1 = 0.0
              , offset2 = 0.0
              , offsetIncrement = 0.002
              }
            , { scale = 27.6
              , multiplier = 0.5
              , offset1 = 0.0
              , offset2 = 0.0
              , offsetIncrement = 0.002
              }
            ]
    }


init : () -> ( Model, Cmd Msg )
init _ =
    let
        model =
            { isOpen = False
            , settings = defaultSettings
            }
    in
    ( model
    , initFlux (encodeSettings model.settings)
    )



-- UPDATE


type Msg
    = ToggleControls
    | SaveSetting SettingMsg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ToggleControls ->
            ( { model | isOpen = not model.isOpen }, Cmd.none )

        SaveSetting settingToUpdate ->
            let
                newSettings =
                    updateSettings settingToUpdate model.settings
            in
            ( { model | settings = newSettings }
            , setSettings (encodeSettings newSettings)
            )


type SettingMsg
    = SetViscosity Float
    | SetVelocityDissipation Float
    | SetStartingPressure Float
    | SetDiffusionIterations Int
    | SetPressureIterations Int
    | SetColorScheme ColorScheme
    | SetLineLength Float
    | SetLineWidth Float
    | SetLineBeginOffset Float
    | SetLineFadeOutLength Float
    | SetSpringVariance Float
    | SetNoiseChannel Int NoiseMsg


type NoiseMsg
    = SetNoiseScale Float
    | SetNoiseMultiplier Float
    | SetNoiseOffset1 Float
    | SetNoiseOffset2 Float
    | SetNoiseOffsetIncrement Float


updateSettings : SettingMsg -> Settings -> Settings
updateSettings msg settings =
    case msg of
        SetViscosity newViscosity ->
            { settings | viscosity = newViscosity }

        SetVelocityDissipation newVelocityDissipation ->
            { settings | velocityDissipation = newVelocityDissipation }

        SetStartingPressure newPressure ->
            { settings | startingPressure = newPressure }

        SetDiffusionIterations newDiffusionIterations ->
            { settings | diffusionIterations = newDiffusionIterations }

        SetPressureIterations newPressureIterations ->
            { settings | pressureIterations = newPressureIterations }

        SetColorScheme newColorScheme ->
            { settings | colorScheme = newColorScheme }

        SetLineLength newLineLength ->
            { settings | lineLength = newLineLength }

        SetLineWidth newLineWidth ->
            { settings | lineWidth = newLineWidth }

        SetLineBeginOffset newLineBeginOffset ->
            { settings | lineBeginOffset = newLineBeginOffset }

        SetLineFadeOutLength newLineFadeOutLength ->
            { settings | lineFadeOutLength = newLineFadeOutLength / settings.lineLength }

        SetSpringVariance newSpringVariance ->
            { settings | springVariance = newSpringVariance }

        SetNoiseChannel channelNumber noiseMsg ->
            let
                maybeChannel =
                    Array.get channelNumber settings.noiseChannels
            in
            case maybeChannel of
                Just channel ->
                    { settings | noiseChannels = Array.set channelNumber (updateNoise noiseMsg channel) settings.noiseChannels }

                Nothing ->
                    settings


updateNoise : NoiseMsg -> Noise -> Noise
updateNoise msg noise =
    case msg of
        SetNoiseScale newScale ->
            { noise | scale = newScale }

        SetNoiseMultiplier newMultiplier ->
            { noise | multiplier = newMultiplier }

        SetNoiseOffset1 newOffset ->
            { noise | offset1 = newOffset }

        SetNoiseOffset2 newOffset ->
            { noise | offset2 = newOffset }

        SetNoiseOffsetIncrement newOffsetIncrement ->
            { noise | offsetIncrement = newOffsetIncrement }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions { isOpen } =
    if isOpen then
        Sub.batch
            [ BrowserEvent.onKeyDown (decodeKeyCode "Escape" ToggleControls)
            , BrowserEvent.onKeyDown (decodeKeyCode "KeyC" ToggleControls)
            ]

    else
        BrowserEvent.onKeyDown (decodeKeyCode "KeyC" ToggleControls)



-- VIEW


type alias Control value =
    { title : String
    , description : String
    , input : Input value
    }


type Input number
    = Slider
        { min : number
        , max : number
        , step : number
        , value : number
        , onInput : String -> Msg
        , toString : number -> String
        }


view : Model -> Html Msg
view model =
    let
        classNameWhen className condition =
            if condition then
                className

            else
                ""
    in
    Html.div []
        [ Html.div
            [ HA.class "control-panel"
            , HA.class (classNameWhen "visible" model.isOpen)
            , HA.attribute "role" "dialog"
            , HA.attribute "aria-modal" "true"
            , HA.attribute "aria-labelledby" "control-title"
            , HA.attribute "aria-describedby" "control-description"
            , HA.tabindex -1
            , HA.hidden (not model.isOpen)
            ]
            [ Html.div
                [ HA.class "control-container" ]
                [ viewSettings model.settings ]
            ]
        , Html.footer []
            [ Html.ul [ HA.class "nav" ]
                [ Html.li []
                    [ Html.button
                        [ Event.onClick ToggleControls
                        , HA.type_ "button"
                        , HA.class (classNameWhen "active" model.isOpen)
                        , HA.class "whitespace-nowrap"
                        ]
                        [ Html.text "🄲 Controls" ]
                    ]
                , Html.li []
                    [ Html.a
                        [ HA.href "https://github.com/sandydoo/" ]
                        [ Html.text "© 2021 Sander Melnikov" ]
                    ]
                , Html.li []
                    [ Html.a
                        [ HA.href "https://twitter.com/sandy_doo/" ]
                        [ Html.text "Follow me on Twitter" ]
                    ]
                ]
            ]
        ]


viewSettings : Settings -> Html Msg
viewSettings settings =
    Html.ul
        [ HA.class "control-list" ]
    <|
        [ Html.div
            [ HA.class "col-span-2-md" ]
            [ Html.button
                [ Event.onClick ToggleControls
                , HA.type_ "button"
                , HA.class "text-secondary"
                ]
                [ Html.text "← Back" ]
            , Html.h2 [ HA.id "control-title" ] [ Html.text "Controls" ]
            , Html.p
                [ HA.class "control-description" ]
                [ Html.text
                    """
                    Use this collection of knobs and dials to adjust the look and feel of the fluid simulation.
                    """
                ]
            ]
        , Html.h2 [ HA.class "col-span-2-md" ] [ Html.text "Colors" ]
        , viewButtonGroup (SetColorScheme >> SaveSetting)
            settings.colorScheme
            [ ( "Plasma", Plasma )
            , ( "Peacock", Peacock )
            , ( "Poolside", Poolside )
            , ( "Pollen", Pollen )
            ]
        , Html.h2
            [ HA.class "col-span-2-md" ]
            [ Html.text "Look" ]
        , viewControl <|
            Control
                "Line length"
                """
                The maximum length of a line.
                """
                (Slider
                    { min = 1.0
                    , max = 500.0
                    , step = 1.0
                    , value = settings.lineLength
                    , onInput =
                        \value ->
                            String.toFloat value
                                |> Maybe.withDefault 0.0
                                |> SetLineLength
                                |> SaveSetting
                    , toString = formatFloat 0
                    }
                )
        , viewControl <|
            Control
                "Line width"
                """
                The maximum width of a line.
                """
                (Slider
                    { min = 1.0
                    , max = 20.0
                    , step = 0.1
                    , value = settings.lineWidth
                    , onInput =
                        \value ->
                            String.toFloat value
                                |> Maybe.withDefault 0.0
                                |> SetLineWidth
                                |> SaveSetting
                    , toString = formatFloat 1
                    }
                )
        , viewControl <|
            Control
                "Line fade offset"
                """
                The point along a line when it begins to fade out.
                """
                (Slider
                    { min = 0.0
                    , max = 1.0
                    , step = 0.01
                    , value = settings.lineBeginOffset
                    , onInput =
                        \value ->
                            String.toFloat value
                                |> Maybe.withDefault 0.0
                                |> SetLineBeginOffset
                                |> SaveSetting
                    , toString = formatFloat 2
                    }
                )
        , viewControl <|
            let
                toAbsoluteLength : Float -> Float
                toAbsoluteLength offset =
                    settings.lineLength * offset
            in
            Control
                "Fog level"
                """
                Adjust the height of the fog which consumes shorter lines.
                """
                (Slider
                    { min = 0.0
                    , max = toAbsoluteLength 0.5
                    , step = 0.1
                    , value = toAbsoluteLength settings.lineFadeOutLength
                    , onInput =
                        \value ->
                            String.toFloat value
                                |> Maybe.withDefault 0.0
                                |> SetLineFadeOutLength
                                |> SaveSetting
                    , toString = formatFloat 1
                    }
                )
        , viewControl <|
            Control
                "Variance"
                """
                Give each line a slightly different amount of mass.
                """
                (Slider
                    { min = 0.0
                    , max = 1.0
                    , step = 0.01
                    , value = settings.springVariance
                    , onInput =
                        \value ->
                            String.toFloat value
                                |> Maybe.withDefault 0.0
                                |> SetSpringVariance
                                |> SaveSetting
                    , toString = formatFloat 2
                    }
                )
        , Html.h2 [ HA.class "col-span-2-md" ] [ Html.text "Fluid simulation" ]
        , viewControl <|
            Control
                "Viscosity"
                """
                A viscous fluid resists any change to its velocity.
                It spreads out and diffuses any force applied to it.
                """
                (Slider
                    { min = 0.1
                    , max = 4.0
                    , step = 0.1
                    , value = settings.viscosity
                    , onInput =
                        \value ->
                            String.toFloat value
                                |> Maybe.withDefault 0.0
                                |> SetViscosity
                                |> SaveSetting
                    , toString = formatFloat 1
                    }
                )
        , viewControl <|
            Control
                "Velocity dissipation"
                """
                Velocity should decrease, or dissipate, as it travels through a fluid.
                """
                (Slider
                    { min = 0.0
                    , max = 2.0
                    , step = 0.1
                    , value = settings.velocityDissipation
                    , onInput =
                        \value ->
                            String.toFloat value
                                |> Maybe.withDefault 0.0
                                |> SetVelocityDissipation
                                |> SaveSetting
                    , toString = formatFloat 1
                    }
                )
        , viewControl <|
            Control
                "Starting pressure"
                """
                The amount of fluid pressure we assume before actually calculating pressure.
                """
                (Slider
                    { min = 0.0
                    , max = 1.0
                    , step = 0.1
                    , value = settings.startingPressure
                    , onInput =
                        \value ->
                            String.toFloat value
                                |> Maybe.withDefault 0.0
                                |> SetStartingPressure
                                |> SaveSetting
                    , toString = formatFloat 1
                    }
                )
        , viewControl <|
            Control
                "Diffusion iterations"
                """
                Viscous fluids dissipate velocity through a process called “diffusion”.
                Each iteration enchances this effect and the diffusion strength is controlled by the fluid’s viscosity.
                """
                (Slider
                    { min = 0
                    , max = 30
                    , step = 1
                    , value = settings.diffusionIterations
                    , onInput =
                        \value ->
                            String.toInt value
                                |> Maybe.withDefault 0
                                |> SetDiffusionIterations
                                |> SaveSetting
                    , toString = String.fromInt
                    }
                )
        , viewControl <|
            Control
                "Pressure iterations"
                """
                Applying a force to fluid creates pressure as the fluid pushes back.
                Calculating pressure is expensive, but the fluid will look unrealistic with fewer than 20 iterations.
                """
                (Slider
                    { min = 0
                    , max = 60
                    , step = 1
                    , value = settings.pressureIterations
                    , onInput =
                        \value ->
                            String.toInt value
                                |> Maybe.withDefault 0
                                |> SetPressureIterations
                                |> SaveSetting
                    , toString = String.fromInt
                    }
                )
        , Html.h2
            [ HA.class "col-span-2-md" ]
            [ Html.text "Noise" ]
        ]
            ++ Array.toList (Array.indexedMap (\index channel -> viewNoiseChannel ("Channel " ++ String.fromInt (index + 1)) (SetNoiseChannel index) channel) settings.noiseChannels)


viewButtonGroup : (value -> msg) -> value -> List ( String, value ) -> Html msg
viewButtonGroup onClick active options =
    let
        isActive : value -> String
        isActive value =
            if value == active then
                "active"

            else
                ""
    in
    Html.div [ HA.class "button-group col-span-2-md" ] <|
        List.map
            (\( name, value ) ->
                Html.button
                    [ HA.type_ "button"
                    , HA.class "button"
                    , HA.class (isActive value)
                    , Event.onClick (onClick value)
                    ]
                    [ Html.text name ]
            )
            options


viewNoiseChannel : String -> (NoiseMsg -> SettingMsg) -> Noise -> Html Msg
viewNoiseChannel title setNoiseChannel noiseChannel =
    Html.div
        [ HA.class "control-list-single" ]
        [ Html.div []
            [ Html.h4 [] [ Html.text title ]
            ]
        , viewControl <|
            Control
                "Scale"
                ""
                (Slider
                    { min = 0.1
                    , max = 30.0
                    , step = 0.1
                    , value = noiseChannel.scale
                    , onInput =
                        \value ->
                            String.toFloat value
                                |> Maybe.withDefault 0.0
                                |> SetNoiseScale
                                |> setNoiseChannel
                                |> SaveSetting
                    , toString = formatFloat 1
                    }
                )
        , viewControl <|
            Control
                "Strength"
                ""
                (Slider
                    { min = 0.0
                    , max = 1.0
                    , step = 0.01
                    , value = noiseChannel.multiplier
                    , onInput =
                        \value ->
                            String.toFloat value
                                |> Maybe.withDefault 0.0
                                |> SetNoiseMultiplier
                                |> setNoiseChannel
                                |> SaveSetting
                    , toString = formatFloat 2
                    }
                )
        , viewControl <|
            Control
                "Offset 1"
                ""
                (Slider
                    { min = 0.0
                    , max = 100.0
                    , step = 1.0
                    , value = noiseChannel.offset1
                    , onInput =
                        \value ->
                            String.toFloat value
                                |> Maybe.withDefault 0.0
                                |> SetNoiseOffset1
                                |> setNoiseChannel
                                |> SaveSetting
                    , toString = formatFloat 1
                    }
                )
        , viewControl <|
            Control
                "Offset 2"
                ""
                (Slider
                    { min = 0.0
                    , max = 100.0
                    , step = 1.0
                    , value = noiseChannel.offset2
                    , onInput =
                        \value ->
                            String.toFloat value
                                |> Maybe.withDefault 0.0
                                |> SetNoiseOffset2
                                |> setNoiseChannel
                                |> SaveSetting
                    , toString = formatFloat 1
                    }
                )
        , viewControl <|
            Control
                "Offset increment"
                ""
                (Slider
                    { min = 0.0
                    , max = 1.0
                    , step = 0.01
                    , value = noiseChannel.offsetIncrement
                    , onInput =
                        \value ->
                            String.toFloat value
                                |> Maybe.withDefault 0.0
                                |> SetNoiseOffsetIncrement
                                |> setNoiseChannel
                                |> SaveSetting
                    , toString = formatFloat 2
                    }
                )
        ]


viewControl : Control number -> Html Msg
viewControl { title, description, input } =
    let
        id =
            toKebabcase title
    in
    Html.li [ HA.class "control" ]
        [ Html.label
            [ HA.for id ]
            [ Html.h3
                [ HA.class "control-title" ]
                [ Html.text title ]
            , Html.p
                [ HA.class "control-description" ]
                [ Html.text description ]
            , Html.div [ HA.class "control-slider" ] <|
                case input of
                    Slider slider ->
                        [ Html.input
                            [ HA.id id
                            , HA.type_ "range"
                            , HA.min <| slider.toString slider.min
                            , HA.max <| slider.toString slider.max
                            , HA.step <| slider.toString slider.step
                            , HA.value <| slider.toString slider.value
                            , Event.onInput slider.onInput
                            ]
                            []
                        , Html.span
                            [ HA.class "control-value" ]
                            [ Html.text <| slider.toString slider.value ]
                        ]
            ]
        ]


formatFloat : Int -> Float -> String
formatFloat decimals value =
    F.format
        { decimals = F.Exact decimals
        , system = F.Western
        , thousandSeparator = ","
        , decimalSeparator = "."
        , negativePrefix = "−"
        , negativeSuffix = ""
        , positivePrefix = ""
        , positiveSuffix = ""
        , zeroPrefix = ""
        , zeroSuffix = ""
        }
        value


toKebabcase : String -> String
toKebabcase =
    let
        -- This only converts titles separated by spaces
        kebabify char =
            if char == ' ' then
                '-'

            else
                Char.toLower char
    in
    String.map kebabify



-- JSON


decodeKeyCode : String -> msg -> Decode.Decoder msg
decodeKeyCode key msg =
    Decode.field "code" Decode.string
        |> Decode.andThen
            (\string ->
                if string == key then
                    Decode.succeed msg

                else
                    Decode.fail ""
            )


encodeSettings : Settings -> Encode.Value
encodeSettings settings =
    Encode.object
        [ ( "viscosity", Encode.float settings.viscosity )
        , ( "velocityDissipation", Encode.float settings.velocityDissipation )
        , ( "startingPressure", Encode.float settings.startingPressure )
        , ( "fluidSize", Encode.int settings.fluidSize )
        , ( "fluidSimulationFrameRate", Encode.int settings.fluidSimulationFrameRate )
        , ( "diffusionIterations", Encode.int settings.diffusionIterations )
        , ( "pressureIterations", Encode.int settings.pressureIterations )
        , ( "colorScheme", encodeColorScheme settings.colorScheme )
        , ( "lineLength", Encode.float settings.lineLength )
        , ( "lineWidth", Encode.float settings.lineWidth )
        , ( "lineBeginOffset", Encode.float settings.lineBeginOffset )
        , ( "lineFadeOutLength", Encode.float settings.lineFadeOutLength )
        , ( "springVariance", Encode.float settings.springVariance )
        , ( "gridSpacing", Encode.int settings.gridSpacing )
        , ( "viewScale", Encode.float settings.viewScale )
        , ( "noiseChannels", Encode.array encodeNoise settings.noiseChannels )
        ]


encodeColorScheme : ColorScheme -> Encode.Value
encodeColorScheme =
    colorSchemeToString >> Encode.string


colorSchemeToString : ColorScheme -> String
colorSchemeToString colorscheme =
    case colorscheme of
        Plasma ->
            "Plasma"

        Peacock ->
            "Peacock"

        Poolside ->
            "Poolside"

        Pollen ->
            "Pollen"


encodeNoise : Noise -> Encode.Value
encodeNoise noise =
    Encode.object
        [ ( "scale", Encode.float noise.scale )
        , ( "multiplier", Encode.float noise.multiplier )
        , ( "offset1", Encode.float noise.offset1 )
        , ( "offset2", Encode.float noise.offset2 )
        , ( "offsetIncrement", Encode.float noise.offsetIncrement )
        ]
