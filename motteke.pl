#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Encode (qw/decode_utf8/);

# 標準出力を自動的にutf8にする (Wide character なんちゃら避け)
binmode STDOUT, ':utf8';

# TSVファイルからアイテムデータを読み込む
my $file_path = './items.tsv';
my $items = load_tsv($file_path);

# C列"数量"に登場する言葉を、ユーザーに確認するためにまとめておく
my $conditions = get_conditions($items);

# 対話式でユーザーに泊数を確認
print "何泊しますか？ 自然数を入力してください。: ";
my $number_of_nights = <STDIN>;
chomp($number_of_nights);

# C列"数量"に登場する事柄を対話形式で確認
print "\n以下の質問は、該当する場合のみ'y'と答えてください。\n";
for my $word ( sort keys %$conditions ) {
    print $word . "？: ";
    my $input = <STDIN>;
    chomp($input);
    if ( ($input // '') eq 'y' ) {
        $conditions->{$word} = 1;
    }
}

# 条件に合う持ち物のリストを出力する
print "\nもってけリスト\n";
my $i = 0;
my @words = sort { length($a) <=> length($b) } keys %$conditions;
for my $item ( @$items ) {
    my $number = $item->{number};

    unless ( $number =~ m/\A\d+\z/ ) {
        $number =~ s/泊数/$number_of_nights/g;

        for my $word ( @words ) {
            my $answer = $conditions->{$word};
            $number =~ s/$word/$answer/g;
        }

        $number = eval($number);
    }

    if ( $number ) {
        print sprintf("%02d %s %s * %s%s\n",
            $i++,
            $item->{container},
            $item->{name},
            $number,
            $item->{unit},
        );
    }
}
print "\n良い旅を！\n";


# TSVからアイテムデータを読み込む
sub load_tsv {
    my $file_path = shift;

    # 対象TSVの改行コードを指定
    local $/ = "\r\n";

    my @rows;
    open my $fh, "<", $file_path or die;
    while ( defined(my $row = <$fh>) ) {
        chomp($row);
        if ( defined $row ) {
            # 外から読み込んだ文字列なのでutf8フラグをつけてあげる
            push @rows, decode_utf8($row);
        }
    }

    # 先頭行は要らないので捨てる
    shift @rows;

    # タブ区切りの行をハッシュに変換し、リファレンスを配列へ
    my @items;
    for my $row ( @rows ) {
        my @cols = split(/\t/, $row);

        push @items, {
            container    => $cols[0], # A列 入れ物
            name         => $cols[1], # B列 品名
            number       => $cols[2], # C列 数量
            unit         => $cols[3], # D列 単位
        };
    }

    return \@items;
}

# ユーザーへの確認事項をハッシュのキーとしてまとめる
sub get_conditions {
    my $items = shift;

    my $conditions = {};

    # 数量を示す文字列から言葉を取り出し、ハッシュのキーにする
    for my $item ( @$items ) {
        my $str = $item->{number}; # C列 数量

        # 数字と記号は無視
        $str =~ s/\d|\W/ /g;

        my @words = split(/ +/, $str);
        for my $word ( @words ) {
            if ( $word ) {
                $conditions->{$word} //= 0;
            }
        }
    }

    # 泊数だけは別途確認するので消しておく
    delete $conditions->{"泊数"};

    return $conditions;
}

exit(0);

