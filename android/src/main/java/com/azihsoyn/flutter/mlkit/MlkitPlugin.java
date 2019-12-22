package com.azihsoyn.flutter.mlkit;

import android.app.Activity;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.graphics.Point;
import android.graphics.Rect;
import android.media.ExifInterface;
import android.net.Uri;
import android.content.res.AssetManager;
import android.content.res.AssetFileDescriptor;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import android.util.Log;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Array;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Objects;

import java.io.ByteArrayInputStream;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.firebase.ml.naturallanguage.FirebaseNaturalLanguage;
import com.google.firebase.ml.naturallanguage.smartreply.FirebaseSmartReply;
import com.google.firebase.ml.naturallanguage.smartreply.FirebaseTextMessage;
import com.google.firebase.ml.naturallanguage.smartreply.SmartReplySuggestion;
import com.google.firebase.ml.naturallanguage.smartreply.SmartReplySuggestionResult;

import java.util.ArrayList;

/**
 * MlkitPlugin
 */
public class MlkitPlugin implements MethodCallHandler {
    private static Context context;
    private static Activity activity;
    private static ArrayList conversation = new ArrayList();
    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "plugins.flutter.io/mlkit");
        channel.setMethodCallHandler(new MlkitPlugin());
        context = registrar.context();
        activity = registrar.activity();
    }

    @Override
    public void onMethodCall(MethodCall call, final Result result) {
        if(call.method.equals("clear")){
            conversation.clear();
        }else
        if (call.method.equals("createForLocalUser")) {
            conversation.add(FirebaseTextMessage.createForLocalUser(
                    call.argument("message").toString(), (long)call.argument("time")));
        } else if(call.method.equals("createForRemoteUser")){
            conversation.add(FirebaseTextMessage.createForRemoteUser(
                    call.argument("message").toString(), (long)call.argument("time"), call.argument("userId").toString()));
        }else if(call.method.equals("suggest")){
            FirebaseSmartReply smartReply = FirebaseNaturalLanguage.getInstance().getSmartReply();
            smartReply.suggestReplies(conversation)
                    .addOnSuccessListener(new OnSuccessListener<SmartReplySuggestionResult>() {
                        @Override
                        public void onSuccess(SmartReplySuggestionResult res) {
                            if (res.getStatus() == SmartReplySuggestionResult.STATUS_NOT_SUPPORTED_LANGUAGE) {
                                Log.e("asa","empty");
                                result.success(new ArrayList<>());
                            } else if (res.getStatus() == SmartReplySuggestionResult.STATUS_SUCCESS) {
                                Log.e("asa","here");
                                ArrayList<String> test = new ArrayList();
                                for (SmartReplySuggestion suggestion : res.getSuggestions()) {
                                    String replyText = suggestion.getText();
                                    test.add(replyText);
                                }
                                result.success(test);
                            }
                        }
                    })
                    .addOnFailureListener(new OnFailureListener() {
                        @Override
                        public void onFailure(@NonNull Exception e) {
                            Log.e("asa",e.getMessage());
                            result.success(new ArrayList<>());
                        }
                    });
        }
        else {
            result.notImplemented();
        }
    }
}
