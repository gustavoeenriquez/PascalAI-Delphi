object FPrincipal: TFPrincipal
  Left = 0
  Top = 0
  Caption = 'Reglas de descuento con PascalAI'
  ClientHeight = 560
  ClientWidth = 820
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 17
  object Divisor: TSplitter
    Left = 0
    Top = 400
    Width = 820
    Height = 4
    Cursor = crVSplit
    Align = alBottom
  end
  object PanelPedido: TPanel
    Left = 0
    Top = 0
    Width = 820
    Height = 48
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object LblProducto: TLabel
      Left = 12
      Top = 15
      Width = 56
      Height = 17
      Caption = 'Producto'
    end
    object LblCantidad: TLabel
      Left = 236
      Top = 15
      Width = 54
      Height = 17
      Caption = 'Cantidad'
    end
    object EdProducto: TEdit
      Left = 76
      Top = 12
      Width = 145
      Height = 25
      TabOrder = 0
      Text = 'cafetera'
    end
    object EdCantidad: TEdit
      Left = 298
      Top = 12
      Width = 57
      Height = 25
      TabOrder = 1
      Text = '12'
    end
    object ChkVip: TCheckBox
      Left = 372
      Top = 14
      Width = 97
      Height = 21
      Caption = 'Cliente VIP'
      TabOrder = 2
    end
    object BtnCalcular: TButton
      Left = 484
      Top = 10
      Width = 105
      Height = 29
      Caption = 'Calcular'
      Default = True
      TabOrder = 3
      OnClick = BtnCalcularClick
    end
  end
  object MemoReglas: TMemo
    Left = 0
    Top = 48
    Width = 820
    Height = 352
    Align = alClient
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -14
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ScrollBars = ssBoth
    TabOrder = 1
    WordWrap = False
  end
  object MemoResultado: TMemo
    Left = 0
    Top = 404
    Width = 820
    Height = 156
    Align = alBottom
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 2
  end
  object Motor: TPaiEngine
    Profile = spPure
    Left = 720
    Top = 72
  end
end
