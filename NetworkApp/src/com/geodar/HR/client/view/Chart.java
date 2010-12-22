package com.geodar.HR.client.view;

import java.util.Date;

import com.google.gwt.core.client.GWT;
import com.google.gwt.http.client.Request;
import com.google.gwt.http.client.RequestBuilder;
import com.google.gwt.http.client.RequestCallback;
import com.google.gwt.http.client.RequestException;
import com.google.gwt.http.client.Response;
import com.google.gwt.http.client.URL;
import com.google.gwt.json.client.JSONArray;
import com.google.gwt.json.client.JSONException;
import com.google.gwt.json.client.JSONNumber;
import com.google.gwt.json.client.JSONObject;
import com.google.gwt.json.client.JSONParser;
import com.google.gwt.json.client.JSONString;
import com.google.gwt.json.client.JSONValue;
import com.google.gwt.user.client.Window;
import com.google.gwt.user.client.ui.VerticalPanel;
import com.google.gwt.visualization.client.AbstractDataTable;
import com.google.gwt.visualization.client.AbstractDataTable.ColumnType;
import com.google.gwt.visualization.client.DataTable;
import com.google.gwt.visualization.client.VisualizationUtils;
import com.google.gwt.visualization.client.visualizations.AnnotatedTimeLine;
import com.google.gwt.visualization.client.visualizations.AnnotatedTimeLine.ScaleType;

public class Chart extends VerticalPanel {
	private String query;
	private DataTable data;
	private AnnotatedTimeLine atl = null;
	private String url;

	RequestBuilder builder;

	public Chart(String query) {
		this.query = query;
		this.url = URL.encode("http://" + Window.Location.getHost() + Configuration.ChartURL + query);
		GWT.log(url);
		builder = new RequestBuilder(RequestBuilder.GET, url);
		// Create a callback to be called when the visualization API
		// has been loaded.
		Runnable onLoadCallback = new Runnable() {
			public void run() {
				atl = new AnnotatedTimeLine(createTable(), createOptions(), "750px", "300px");
				// Add a chart visualization.
				add(atl);
				updateGraph();
			}
		};

		// Load the visualization api, passing the onLoadCallback to be called
		// when loading is done.
		VisualizationUtils.loadVisualizationApi(onLoadCallback, AnnotatedTimeLine.PACKAGE);

	}

	private AnnotatedTimeLine.Options createOptions() {
		AnnotatedTimeLine.Options options = AnnotatedTimeLine.Options.create();
		options.setDisplayAnnotations(false);
		options.setScaleType(ScaleType.MAXIMIZE);
		return options;
	}

	private AbstractDataTable createTable() {

		data = DataTable.create();
		data.addColumn(ColumnType.DATETIME, "Date");
		data.addColumn(ColumnType.NUMBER, query);
		return data;

	}

	private void updateGraph() {

		// add watch list stock symbols to URL
		System.out.println("Updating graph");

		try {
			builder.sendRequest(null, new RequestCallback() {
				public void onError(Request request, Throwable exception) {
					displayError("Couldn't retrieve JSON");
				}

				public void onResponseReceived(Request request, Response response) {
					if (200 == response.getStatusCode()) {
						try {
							// parse the response text into JSON
							JSONValue jsonValue = JSONParser.parseStrict(response.getText());
							System.out.println("response:" + response.getText());
							JSONArray jsonArray = jsonValue.isArray();

							if (jsonArray != null) {
								System.out.println("Got " + jsonArray.toString());
								updateTable(jsonArray);
							} else {
								throw new JSONException();
							}
						} catch (JSONException e) {
							displayError("Could not parse JSON");
							// System.err.println(e.toString());
							// e.printStackTrace();
						}
					} else {
						displayError("Couldn't retrieve JSON (" + response.getStatusText() + ")");
					}
				}

			});
		} catch (RequestException e) {
			displayError("Couldn't retrieve JSON");
		} catch (Exception e) {
			displayError(e.getStackTrace().toString());
		}
	}

	private void displayError(String error) {
		System.out.println(error);
		// errorMsgLabel.setVisible(true);
	}

	private void updateTable(JSONArray array) {
		JSONValue jsonValue;
		data.removeRows(0, data.getNumberOfRows()-1);

		data.addRows(array.size());
		GWT.log("array size : "+ array.size());
		for (int i = 0; i < array.size(); i++) {
			JSONObject jsEntry;
			JSONNumber jsVal;
			JSONString jsDate;

			if ((jsEntry = array.get(i).isObject()) == null) {
				continue;
			}

			if ((jsonValue = jsEntry.get("value")) == null) {
				continue;
			}
			if ((jsVal = jsonValue.isNumber()) == null) {
				continue;
			}
			//GWT.log("jsVal : "+ jsVal);
			if ((jsonValue = jsEntry.get("date")) == null) {
				continue;
			}
			if ((jsDate = jsonValue.isString()) == null) {
				continue;
			}
			//GWT.log("jsDate : "+ jsDate);
			data.setValue(i, 0, getDate(jsDate.stringValue()));

			//GWT.log("added Date : "+ getDate(jsDate.stringValue()));
			data.setValue(i, 1, jsVal.doubleValue());
			//GWT.log("added value : "+ jsVal.doubleValue());

		}
		atl.draw(data);

	}

	@SuppressWarnings("deprecation")
	private Date getDate(String str) {
		String[] a = str.split(" ");
		String[] b = a[0].split("-");
		String[] c = a[1].split(":");
		int year, month, day, hrs, min, sec;
		try {
			year = Integer.parseInt(b[0]);
			month = Integer.parseInt(b[1]);
			day = Integer.parseInt(b[2]);
			hrs = Integer.parseInt(c[0]);
			min = Integer.parseInt(c[1]);
			sec = Integer.parseInt(c[2]);
		} catch (Exception e) {
			return new Date();
		}
		return new Date(year - 1900, month - 1, day, hrs, min, sec);
	}

	public String getQuery() {
		return query;
	}

	public void setQuery(String query) {
		this.query = query;
	}

	public String getUrl() {
		return url;
	}

	public void setUrl(String url) {
		this.url = url;
	}

}